using System.Diagnostics;
using System.IO.Compression;
using System.Net;
using System.Net.Http.Headers;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

namespace LocalStoreManagement.Desktop.Services;

public sealed class ApplicationUpdateService
{
    private const string Owner = "MaydayAlaska";
    private const string Repository = "Local-Store-Management-System";
    private const string StableBranch = "main";
    private const string TokenEnvironmentVariable = "LOCAL_STORE_GITHUB_TOKEN";

    private readonly HttpClient _httpClient;
    private readonly LocalBuildInfo? _localBuildInfo;

    public ApplicationUpdateService()
    {
        _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromMinutes(5)
        };
        _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("LocalStoreManagementSystem-Updater/1.0");
        _httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
        _httpClient.DefaultRequestHeaders.Add("X-GitHub-Api-Version", "2022-11-28");

        var token = Environment.GetEnvironmentVariable(TokenEnvironmentVariable)?.Trim();
        if (!string.IsNullOrWhiteSpace(token))
        {
            _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        }

        _localBuildInfo = ReadLocalBuildInfo();
    }

    public string CurrentVersion => FormatVersion(Assembly.GetEntryAssembly()?.GetName().Version);

    public bool IsInstalledBuild => !string.IsNullOrWhiteSpace(_localBuildInfo?.Commit);

    public async Task<UpdateCheckResult> CheckAsync(CancellationToken cancellationToken = default)
    {
        var currentCommit = _localBuildInfo?.Commit?.Trim();
        var latestCommit = await GetMainCommitAsync(cancellationToken);

        if (!string.IsNullOrWhiteSpace(currentCommit) &&
            string.Equals(currentCommit, latestCommit, StringComparison.OrdinalIgnoreCase))
        {
            return new UpdateCheckResult(
                UpdateAvailable: false,
                CanInstall: true,
                CurrentVersion,
                currentCommit,
                latestCommit,
                AssetApiUrl: null,
                Message: "Hai già l'ultima versione pubblicata su main.");
        }

        var releaseTag = $"ota-{latestCommit}";
        var asset = await TryGetReleaseAssetAsync(releaseTag, cancellationToken);

        if (asset is null)
        {
            return new UpdateCheckResult(
                UpdateAvailable: true,
                CanInstall: false,
                CurrentVersion,
                currentCommit,
                latestCommit,
                AssetApiUrl: null,
                Message: IsInstalledBuild
                    ? "È disponibile una nuova revisione su main, ma il pacchetto OTA è ancora in preparazione. Riprova tra poco."
                    : "Build di sviluppo rilevata. L'aggiornamento automatico è disponibile sulle versioni pubblicate/installate.");
        }

        if (!IsInstalledBuild)
        {
            return new UpdateCheckResult(
                UpdateAvailable: true,
                CanInstall: false,
                CurrentVersion,
                currentCommit,
                latestCommit,
                asset.Value.ApiUrl,
                "Su main è presente una versione più recente. Questa esecuzione è una build di sviluppo: usa una release installata per provare l'OTA.");
        }

        return new UpdateCheckResult(
            UpdateAvailable: true,
            CanInstall: true,
            CurrentVersion,
            currentCommit,
            latestCommit,
            asset.Value.ApiUrl,
            "Aggiornamento disponibile da main. Premi «Installa aggiornamento» per scaricarlo e riavviare l'applicazione.");
    }

    public async Task PrepareAndLaunchUpdateAsync(UpdateCheckResult update, CancellationToken cancellationToken = default)
    {
        if (!update.UpdateAvailable || !update.CanInstall || string.IsNullOrWhiteSpace(update.AssetApiUrl))
        {
            throw new InvalidOperationException("Nessun aggiornamento OTA installabile è stato selezionato.");
        }

        var updateRoot = Path.Combine(Path.GetTempPath(), "LocalStoreManagementSystem", "updates", update.LatestCommit);
        var packagePath = Path.Combine(updateRoot, "package.zip");
        var stagingDirectory = Path.Combine(updateRoot, "staging");

        if (Directory.Exists(updateRoot))
        {
            Directory.Delete(updateRoot, recursive: true);
        }

        Directory.CreateDirectory(updateRoot);

        using (var request = new HttpRequestMessage(HttpMethod.Get, update.AssetApiUrl))
        {
            request.Headers.Accept.Clear();
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/octet-stream"));
            using var response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            await EnsureGitHubSuccessAsync(response, "scaricare il pacchetto di aggiornamento", cancellationToken);

            await using var input = await response.Content.ReadAsStreamAsync(cancellationToken);
            await using var output = File.Create(packagePath);
            await input.CopyToAsync(output, cancellationToken);
        }

        Directory.CreateDirectory(stagingDirectory);
        ZipFile.ExtractToDirectory(packagePath, stagingDirectory, overwriteFiles: true);

        var executableName = GetExecutableName();
        var stagedExecutable = Path.Combine(stagingDirectory, executableName);
        if (!File.Exists(stagedExecutable))
        {
            throw new InvalidDataException($"Il pacchetto OTA non contiene {executableName}.");
        }

        var installDirectory = AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var processId = Environment.ProcessId;

        if (OperatingSystem.IsWindows())
        {
            LaunchWindowsUpdater(stagingDirectory, installDirectory, executableName, processId, updateRoot);
            return;
        }

        if (OperatingSystem.IsLinux())
        {
            LaunchLinuxUpdater(stagingDirectory, installDirectory, executableName, processId, updateRoot);
            return;
        }

        throw new PlatformNotSupportedException("L'aggiornamento automatico è disponibile solo su Windows e Linux.");
    }

    private async Task<string> GetMainCommitAsync(CancellationToken cancellationToken)
    {
        var url = $"https://api.github.com/repos/{Owner}/{Repository}/commits/{StableBranch}";
        using var response = await _httpClient.GetAsync(url, cancellationToken);
        await EnsureGitHubSuccessAsync(response, "controllare il branch main", cancellationToken);

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        var sha = document.RootElement.GetProperty("sha").GetString()?.Trim();
        if (string.IsNullOrWhiteSpace(sha))
        {
            throw new InvalidDataException("GitHub non ha restituito l'identificativo del commit di main.");
        }

        return sha;
    }

    private async Task<(string ApiUrl, string Name)?> TryGetReleaseAssetAsync(string releaseTag, CancellationToken cancellationToken)
    {
        var url = $"https://api.github.com/repos/{Owner}/{Repository}/releases/tags/{releaseTag}";
        using var response = await _httpClient.GetAsync(url, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            return null;
        }

        await EnsureGitHubSuccessAsync(response, "leggere il pacchetto OTA", cancellationToken);
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);

        var expectedAssetName = GetAssetName();
        foreach (var asset in document.RootElement.GetProperty("assets").EnumerateArray())
        {
            var name = asset.GetProperty("name").GetString();
            if (!string.Equals(name, expectedAssetName, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var apiUrl = asset.GetProperty("url").GetString();
            if (!string.IsNullOrWhiteSpace(apiUrl))
            {
                return (apiUrl, name ?? expectedAssetName);
            }
        }

        return null;
    }

    private async Task EnsureGitHubSuccessAsync(HttpResponseMessage response, string operation, CancellationToken cancellationToken)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        var body = await response.Content.ReadAsStringAsync(cancellationToken);
        var hasToken = _httpClient.DefaultRequestHeaders.Authorization is not null;
        if ((response.StatusCode == HttpStatusCode.NotFound || response.StatusCode == HttpStatusCode.Unauthorized || response.StatusCode == HttpStatusCode.Forbidden) && !hasToken)
        {
            throw new InvalidOperationException(
                $"Impossibile {operation}: il repository GitHub non è accessibile senza autenticazione. " +
                $"Se il repository resta privato, configura la variabile d'ambiente {TokenEnvironmentVariable} con un token GitHub in sola lettura per questo repository.");
        }

        throw new HttpRequestException(
            $"Impossibile {operation}. GitHub ha risposto {(int)response.StatusCode} {response.ReasonPhrase}. {TrimBody(body)}");
    }

    private static string GetAssetName()
    {
        if (RuntimeInformation.ProcessArchitecture != Architecture.X64)
        {
            throw new PlatformNotSupportedException("I pacchetti OTA sono attualmente predisposti per sistemi x64.");
        }

        if (OperatingSystem.IsWindows()) return "LocalStoreManagement-win-x64.zip";
        if (OperatingSystem.IsLinux()) return "LocalStoreManagement-linux-x64.zip";
        throw new PlatformNotSupportedException("Gli aggiornamenti OTA sono disponibili solo su Windows e Linux.");
    }

    private static string GetExecutableName()
        => OperatingSystem.IsWindows() ? "LocalStoreManagement.Desktop.exe" : "LocalStoreManagement.Desktop";

    private static LocalBuildInfo? ReadLocalBuildInfo()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "build-info.json");
        if (!File.Exists(path))
        {
            return null;
        }

        try
        {
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<LocalBuildInfo>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
        }
        catch
        {
            return null;
        }
    }

    private static string FormatVersion(Version? version)
    {
        if (version is null) return "0.0.0";
        var build = Math.Max(0, version.Build);
        return $"{version.Major}.{version.Minor}.{build}";
    }

    private static string TrimBody(string body)
    {
        var value = body.Replace('\r', ' ').Replace('\n', ' ').Trim();
        return value.Length <= 180 ? value : value[..180] + "…";
    }

    private static void LaunchWindowsUpdater(string source, string destination, string executableName, int processId, string updateRoot)
    {
        var scriptPath = Path.Combine(updateRoot, "apply-update.cmd");
        var script = $"""
@echo off
setlocal
:wait
for /f "tokens=2" %%p in ('tasklist /FI "PID eq {processId}" /NH 2^>NUL') do if "%%p"=="{processId}" (
  timeout /t 1 /nobreak >NUL
  goto wait
)
robocopy "{source}" "{destination}" /E /COPY:DAT /R:3 /W:1 >NUL
start "" "{Path.Combine(destination, executableName)}"
del "%~f0"
""";
        File.WriteAllText(scriptPath, script, Encoding.UTF8);
        Process.Start(new ProcessStartInfo
        {
            FileName = "cmd.exe",
            Arguments = $"/c start \"\" /min \"{scriptPath}\"",
            UseShellExecute = false,
            CreateNoWindow = true
        });
    }

    private static void LaunchLinuxUpdater(string source, string destination, string executableName, int processId, string updateRoot)
    {
        var scriptPath = Path.Combine(updateRoot, "apply-update.sh");
        var executablePath = Path.Combine(destination, executableName);
        var script = $"""
#!/bin/sh
while kill -0 {processId} 2>/dev/null; do
  sleep 1
done
cp -a "{source}/." "{destination}/"
chmod +x "{executablePath}"
nohup "{executablePath}" >/dev/null 2>&1 &
rm -f "$0"
""";
        File.WriteAllText(scriptPath, script, new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        Process.Start(new ProcessStartInfo
        {
            FileName = "/bin/sh",
            Arguments = $"\"{scriptPath}\"",
            UseShellExecute = false,
            CreateNoWindow = true
        });
    }

    private sealed record LocalBuildInfo(string? Version, string? Commit);
}

public sealed record UpdateCheckResult(
    bool UpdateAvailable,
    bool CanInstall,
    string CurrentVersion,
    string? CurrentCommit,
    string LatestCommit,
    string? AssetApiUrl,
    string Message);
