using Avalonia.Controls;
using Avalonia.Platform.Storage;
using LocalStoreManagement.Desktop.Infrastructure;

namespace LocalStoreManagement.Desktop;

public partial class SettingsWindow : Window
{
    private readonly AppSettingsService _settingsService;
    private PendingAppAsset? _pendingIcon;
    private PendingAppAsset? _pendingLogo;

    public SettingsWindow()
        : this(new AppSettingsService())
    {
    }

    public SettingsWindow(AppSettingsService settingsService)
    {
        _settingsService = settingsService;
        InitializeComponent();

        var settings = _settingsService.Load();
        ShopNameInput.Text = settings.ShopName;
        DataDirectoryText.Text = AppPaths.DataDirectory;

        var iconPath = _settingsService.ResolveIconPath(settings);
        IconFileText.Text = iconPath is null
            ? "Nessuna icona personalizzata."
            : $"Attuale: {Path.GetFileName(iconPath)}";

        var logoPath = _settingsService.ResolveLogoPath(settings);
        LogoFileText.Text = logoPath is null
            ? "Nessun logo selezionato."
            : $"Attuale: {Path.GetFileName(logoPath)}";

        Opened += (_, _) => ShopNameInput.Focus();
    }

    private async void ChooseIconButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var asset = await PickImageAsync("Scegli l'icona del programma", allowIco: true);
        if (asset is null)
        {
            return;
        }

        _pendingIcon = asset;
        IconFileText.Text = $"Selezionata: {asset.OriginalFileName}";
    }

    private async void ChooseLogoButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var asset = await PickImageAsync("Scegli il logo del negozio", allowIco: false);
        if (asset is null)
        {
            return;
        }

        _pendingLogo = asset;
        LogoFileText.Text = $"Selezionato: {asset.OriginalFileName}";
    }

    private void SaveButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();

        try
        {
            _settingsService.Save(ShopNameInput.Text ?? string.Empty, _pendingIcon, _pendingLogo);
            Close(true);
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile salvare le impostazioni: {ex.Message}");
        }
    }

    private void CancelButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        Close(false);
    }

    private async Task<PendingAppAsset?> PickImageAsync(string title, bool allowIco)
    {
        HideError();

        if (!StorageProvider.CanOpen)
        {
            ShowError("Il selettore file non è disponibile su questo sistema.");
            return null;
        }

        var patterns = allowIco
            ? new[] { "*.png", "*.jpg", "*.jpeg", "*.bmp", "*.ico" }
            : new[] { "*.png", "*.jpg", "*.jpeg", "*.bmp" };

        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = title,
            AllowMultiple = false,
            FileTypeFilter = new[]
            {
                new FilePickerFileType("Immagini")
                {
                    Patterns = patterns
                }
            }
        });

        var file = files.FirstOrDefault();
        if (file is null)
        {
            return null;
        }

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

            var extension = Path.GetExtension(file.Name);
            return new PendingAppAsset(memory.ToArray(), extension, file.Name);
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile leggere l'immagine: {ex.Message}");
            return null;
        }
    }

    private void ShowError(string message)
    {
        ErrorText.Text = message;
        ErrorPanel.IsVisible = true;
    }

    private void HideError()
    {
        ErrorText.Text = string.Empty;
        ErrorPanel.IsVisible = false;
    }
}
