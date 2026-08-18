using System.Text.Json;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Platform.Storage;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Services;

namespace LocalStoreManagement.Desktop;

public partial class SettingsView : UserControl
{
    private readonly AppSettingsService _settingsService;
    private readonly ApplicationUpdateService _updateService;
    private PendingAppAsset? _pendingIcon;
    private PendingAppAsset? _pendingLogo;
    private UpdateCheckResult? _pendingUpdate;

    public SettingsView() : this(new AppSettingsService()) { }

    public SettingsView(AppSettingsService settingsService)
    {
        _settingsService = settingsService;
        _updateService = new ApplicationUpdateService();
        InitializeComponent();
        Reload();
    }

    public event EventHandler? SettingsSaved;

    public void Reload()
    {
        _pendingIcon = null;
        _pendingLogo = null;
        _pendingUpdate = null;
        HideError();
        StatusText.Text = string.Empty;
        var settings = _settingsService.Load();
        ShopNameInput.Text = settings.ShopName;
        ShowShopNameInMenuInput.IsChecked = settings.ShowShopNameInMenu ?? true;
        ShowLogoInMenuInput.IsChecked = settings.ShowLogoInMenu ?? false;
        DataDirectoryText.Text = AppPaths.DataDirectory;

        var iconPath = _settingsService.ResolveIconPath(settings);
        IconFileText.Text = iconPath is null ? "Nessuna icona personalizzata." : $"Attuale: {Path.GetFileName(iconPath)}";
        var logoPath = _settingsService.ResolveLogoPath(settings);
        LogoFileText.Text = logoPath is null ? "Nessun logo selezionato." : $"Attuale: {Path.GetFileName(logoPath)}";

        var isBetaBuild = IsBetaBuild();
        VersionText.Text = $"v{_updateService.CurrentVersion}{(isBetaBuild ? " BETA" : string.Empty)}";
        CheckUpdatesButton.Content = "Controlla aggiornamenti";
        CheckUpdatesButton.IsEnabled = !isBetaBuild;
        UpdateStatusText.Text = isBetaBuild
            ? "Build BETA/TEST dal branch test. Gli aggiornamenti OTA stabili sono disattivati: scarica l'ultima beta dalla sezione Releases di GitHub."
            : _updateService.IsInstalledBuild
                ? "Canale aggiornamenti: GitHub, branch main."
                : "Build di sviluppo: il controllo è disponibile, ma l'installazione OTA viene abilitata nelle versioni pubblicate.";
    }

    public void FocusPrimaryField() => ShopNameInput.Focus();

    private async void ChooseIconButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var asset = await PickImageAsync("Scegli l'icona del programma", allowIco: true);
        if (asset is null) return;
        _pendingIcon = asset;
        IconFileText.Text = $"Selezionata: {asset.OriginalFileName}";
        StatusText.Text = "Modifiche non ancora salvate.";
    }

    private async void ChooseLogoButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var asset = await PickImageAsync("Scegli il logo del negozio", allowIco: false);
        if (asset is null) return;
        _pendingLogo = asset;
        LogoFileText.Text = $"Selezionato: {asset.OriginalFileName}";
        StatusText.Text = "Modifiche non ancora salvate.";
    }

    private void SaveButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        try
        {
            var savedSettings = _settingsService.Save(
                ShopNameInput.Text ?? string.Empty,
                ShowShopNameInMenuInput.IsChecked ?? false,
                ShowLogoInMenuInput.IsChecked ?? false,
                _pendingIcon,
                _pendingLogo);

            var iconPath = _settingsService.ResolveIconPath(savedSettings);
            if (iconPath is not null && TopLevel.GetTopLevel(this) is Window window)
            {
                ApplicationIconIntegrationService.Apply(window, iconPath);
            }

            _pendingIcon = null;
            _pendingLogo = null;
            StatusText.Text = "Impostazioni salvate.";
            ReloadFileLabels();
            SettingsSaved?.Invoke(this, EventArgs.Empty);
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile salvare le impostazioni: {ex.Message}");
        }
    }

    private async void CheckUpdatesButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        CheckUpdatesButton.IsEnabled = false;

        try
        {
            if (_pendingUpdate is { UpdateAvailable: true, CanInstall: true })
            {
                CheckUpdatesButton.Content = "Installazione...";
                UpdateStatusText.Text = "Download dell'aggiornamento da GitHub e preparazione del riavvio...";
                await _updateService.PrepareAndLaunchUpdateAsync(_pendingUpdate);
                UpdateStatusText.Text = "Aggiornamento pronto. L'applicazione verrà chiusa e riavviata automaticamente.";

                if (Application.Current?.ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
                {
                    desktop.Shutdown();
                    return;
                }

                throw new InvalidOperationException("Impossibile chiudere automaticamente l'applicazione per applicare l'aggiornamento.");
            }

            CheckUpdatesButton.Content = "Controllo...";
            UpdateStatusText.Text = "Controllo del branch main su GitHub...";
            var result = await _updateService.CheckAsync();
            _pendingUpdate = result.CanInstall && result.UpdateAvailable ? result : null;
            UpdateStatusText.Text = result.Message;
            CheckUpdatesButton.Content = _pendingUpdate is not null
                ? "Installa aggiornamento"
                : "Controlla aggiornamenti";
        }
        catch (Exception ex)
        {
            _pendingUpdate = null;
            CheckUpdatesButton.Content = "Controlla aggiornamenti";
            UpdateStatusText.Text = "Controllo aggiornamenti non riuscito.";
            ShowError(ex.Message);
        }
        finally
        {
            CheckUpdatesButton.IsEnabled = true;
        }
    }

    private void ReloadFileLabels()
    {
        var settings = _settingsService.Load();
        var iconPath = _settingsService.ResolveIconPath(settings);
        IconFileText.Text = iconPath is null ? "Nessuna icona personalizzata." : $"Attuale: {Path.GetFileName(iconPath)}";
        var logoPath = _settingsService.ResolveLogoPath(settings);
        LogoFileText.Text = logoPath is null ? "Nessun logo selezionato." : $"Attuale: {Path.GetFileName(logoPath)}";
    }

    private async Task<PendingAppAsset?> PickImageAsync(string title, bool allowIco)
    {
        HideError();
        var storageProvider = TopLevel.GetTopLevel(this)?.StorageProvider;
        if (storageProvider is null || !storageProvider.CanOpen)
        {
            ShowError("Il selettore file non è disponibile su questo sistema.");
            return null;
        }

        var patterns = allowIco
            ? new[] { "*.png", "*.jpg", "*.jpeg", "*.bmp", "*.ico" }
            : new[] { "*.png", "*.jpg", "*.jpeg", "*.bmp" };
        var files = await storageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = title,
            AllowMultiple = false,
            FileTypeFilter = new[] { new FilePickerFileType("Immagini") { Patterns = patterns } }
        });
        var file = files.FirstOrDefault();
        if (file is null) return null;

        try
        {
            await using var stream = await file.OpenReadAsync();
            using var memory = new MemoryStream();
            await stream.CopyToAsync(memory);
            if (memory.Length == 0)
            {
                ShowError("Il file selezionato è vuoto.");
                return null;
            }
            return new PendingAppAsset(memory.ToArray(), Path.GetExtension(file.Name), file.Name);
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile leggere l'immagine: {ex.Message}");
            return null;
        }
    }

    private static bool IsBetaBuild()
    {
        var buildInfoPath = Path.Combine(AppContext.BaseDirectory, "build-info.json");
        if (!File.Exists(buildInfoPath))
        {
            return false;
        }

        try
        {
            using var document = JsonDocument.Parse(File.ReadAllText(buildInfoPath));
            if (!document.RootElement.TryGetProperty("branch", out var branchElement))
            {
                return false;
            }

            return string.Equals(branchElement.GetString()?.Trim(), "test", StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    private void ShowError(string message)
    {
        ErrorText.Text = message;
        ErrorText.IsVisible = true;
    }

    private void HideError()
    {
        ErrorText.Text = string.Empty;
        ErrorText.IsVisible = false;
    }
}
