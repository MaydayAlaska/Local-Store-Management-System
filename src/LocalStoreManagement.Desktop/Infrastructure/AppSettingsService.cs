using System.Text.Json;

namespace LocalStoreManagement.Desktop.Infrastructure;

public sealed record AppSettings(
    string ShopName,
    string? IconFileName,
    string? LogoFileName)
{
    public static AppSettings Default { get; } = new("Negozio", null, null);
}

public sealed class AppSettingsService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public AppSettings Load()
    {
        Directory.CreateDirectory(AppPaths.DataDirectory);
        Directory.CreateDirectory(AppPaths.AssetsDirectory);

        if (!File.Exists(AppPaths.SettingsPath))
        {
            return AppSettings.Default;
        }

        try
        {
            var json = File.ReadAllText(AppPaths.SettingsPath);
            var settings = JsonSerializer.Deserialize<AppSettings>(json, JsonOptions);
            if (settings is null)
            {
                return AppSettings.Default;
            }

            var shopName = string.IsNullOrWhiteSpace(settings.ShopName)
                ? AppSettings.Default.ShopName
                : settings.ShopName.Trim();

            return settings with { ShopName = shopName };
        }
        catch
        {
            return AppSettings.Default;
        }
    }

    public AppSettings Save(
        string shopName,
        PendingAppAsset? icon = null,
        PendingAppAsset? logo = null)
    {
        Directory.CreateDirectory(AppPaths.DataDirectory);
        Directory.CreateDirectory(AppPaths.AssetsDirectory);

        var current = Load();
        var normalizedName = string.IsNullOrWhiteSpace(shopName)
            ? AppSettings.Default.ShopName
            : shopName.Trim();

        var iconFileName = icon is null
            ? current.IconFileName
            : SaveAsset(icon, "app-icon");
        var logoFileName = logo is null
            ? current.LogoFileName
            : SaveAsset(logo, "shop-logo");

        var settings = new AppSettings(normalizedName, iconFileName, logoFileName);
        File.WriteAllText(AppPaths.SettingsPath, JsonSerializer.Serialize(settings, JsonOptions));
        return settings;
    }

    public string? ResolveIconPath(AppSettings? settings = null)
        => ResolveAssetPath((settings ?? Load()).IconFileName);

    public string? ResolveLogoPath(AppSettings? settings = null)
        => ResolveAssetPath((settings ?? Load()).LogoFileName);

    public string? ResolveAssetPath(string? relativeFileName)
    {
        if (string.IsNullOrWhiteSpace(relativeFileName))
        {
            return null;
        }

        var fullPath = Path.GetFullPath(Path.Combine(AppPaths.DataDirectory, relativeFileName));
        var root = Path.GetFullPath(AppPaths.DataDirectory) + Path.DirectorySeparatorChar;
        if (!fullPath.StartsWith(root, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return File.Exists(fullPath) ? fullPath : null;
    }

    private static string SaveAsset(PendingAppAsset asset, string baseFileName)
    {
        var extension = NormalizeImageExtension(asset.Extension);
        var relativePath = Path.Combine("assets", baseFileName + extension);
        var destination = Path.Combine(AppPaths.DataDirectory, relativePath);

        File.WriteAllBytes(destination, asset.Data);
        return relativePath;
    }

    private static string NormalizeImageExtension(string extension)
    {
        var normalized = extension.Trim().ToLowerInvariant();
        if (!normalized.StartsWith('.'))
        {
            normalized = "." + normalized;
        }

        return normalized switch
        {
            ".png" or ".jpg" or ".jpeg" or ".bmp" or ".ico" => normalized,
            _ => throw new InvalidOperationException("Formato immagine non supportato. Usa PNG, JPG, BMP o ICO.")
        };
    }
}

public sealed record PendingAppAsset(byte[] Data, string Extension, string OriginalFileName);
