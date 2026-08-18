using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private readonly AppSettingsService _appSettingsService = new();
    private SettingsView? _settingsView;
    private Image? _sidebarLogoImage;
    private Bitmap? _sidebarLogoBitmap;
    private TextBlock? _sidebarSubtitleText;

    private void ApplySavedSettings()
    {
        var settings = _appSettingsService.Load();
        var showShopName = settings.ShowShopNameInMenu ?? true;
        var showLogo = settings.ShowLogoInMenu ?? false;

        ShopNameText.Text = settings.ShopName;
        ShopNameText.IsVisible = showShopName;
        Title = settings.ShopName == AppSettings.Default.ShopName
            ? "Local Store Management System"
            : $"{settings.ShopName} - Local Store Management System";

        if (ShopNameText.Parent is StackPanel shopHeader)
        {
            _sidebarSubtitleText ??= shopHeader.Children
                .OfType<TextBlock>()
                .FirstOrDefault(text => !ReferenceEquals(text, ShopNameText));
            if (_sidebarSubtitleText is not null)
            {
                _sidebarSubtitleText.IsVisible = showShopName;
            }
            EnsureSidebarLogoImage(shopHeader);
        }

        ApplySidebarLogo(settings, showLogo);

        var iconPath = _appSettingsService.ResolveIconPath(settings);
        if (iconPath is null) return;
        try { Icon = new WindowIcon(iconPath); }
        catch { }
    }

    private void EnsureSidebarLogoImage(StackPanel shopHeader)
    {
        if (_sidebarLogoImage is not null) return;
        _sidebarLogoImage = new Image
        {
            IsVisible = false,
            MaxWidth = 170,
            MaxHeight = 72,
            Stretch = Stretch.Uniform,
            HorizontalAlignment = HorizontalAlignment.Left,
            Margin = new Avalonia.Thickness(0, 0, 0, 8)
        };
        shopHeader.Children.Insert(0, _sidebarLogoImage);
    }

    private void ApplySidebarLogo(AppSettings settings, bool showLogo)
    {
        if (_sidebarLogoImage is null) return;
        _sidebarLogoBitmap?.Dispose();
        _sidebarLogoBitmap = null;
        _sidebarLogoImage.Source = null;
        _sidebarLogoImage.IsVisible = false;
        if (!showLogo) return;

        var logoPath = _appSettingsService.ResolveLogoPath(settings);
        if (logoPath is null) return;
        try
        {
            _sidebarLogoBitmap = new Bitmap(logoPath);
            _sidebarLogoImage.Source = _sidebarLogoBitmap;
            _sidebarLogoImage.IsVisible = true;
        }
        catch
        {
            _sidebarLogoImage.Source = null;
            _sidebarLogoImage.IsVisible = false;
        }
    }

    private void SettingsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowSettings();

    private void ShowSettings()
    {
        HideEmbeddedViews();
        HideAllPanels();
        EnsureSettingsView();
        _settingsView!.Reload();
        _settingsView.IsVisible = true;
        PageTitle.Text = "Impostazioni";
        PageSubtitle.Text = "Nome negozio, icona, logo e dati dell'applicazione";
        _settingsView.FocusPrimaryField();
    }

    private void EnsureSettingsView()
    {
        if (_settingsView is not null) return;
        if (DashboardPanel.Parent is not Grid contentGrid) throw new InvalidOperationException("Impossibile inizializzare il pannello Impostazioni.");
        _settingsView = new SettingsView(_appSettingsService) { IsVisible = false };
        _settingsView.SettingsSaved += (_, _) => ApplySavedSettings();
        contentGrid.Children.Add(_settingsView);
    }

    private void HideSettingsView()
    {
        if (_settingsView is not null) _settingsView.IsVisible = false;
    }

    private void HideEmbeddedViews()
    {
        HideSettingsView();
        HideBrandsView();
        HideCategoriesView();
        HideExportView();
    }

    private void DashboardProductSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e) => ReloadDashboardProductSearch();

    private async void DashboardOpenProductButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => await OpenDashboardSelectedProductAsync();

    private async void DashboardProductsList_OnDoubleTapped(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => await OpenDashboardSelectedProductAsync();

    private void ReloadDashboardProductSearch()
    {
        var query = DashboardProductSearchInput.Text?.Trim();
        if (string.IsNullOrWhiteSpace(query))
        {
            DashboardProductsList.ItemsSource = null;
            DashboardSearchStatusText.Text = "Cerca un prodotto per nome, SKU o barcode.";
            return;
        }

        var products = _productRepository.Search(query).Take(12).ToList();
        DashboardProductsList.ItemsSource = products;
        DashboardSearchStatusText.Text = products.Count switch
        {
            0 => "Nessun prodotto trovato.",
            1 => "1 prodotto trovato. Doppio clic per aprirlo.",
            _ => $"{products.Count} prodotti mostrati. Doppio clic per aprire quello desiderato."
        };
    }

    private async Task OpenDashboardSelectedProductAsync()
    {
        if (DashboardProductsList.SelectedItem is not Product product) return;
        var latest = _productRepository.GetById(product.Id);
        if (latest is null)
        {
            ReloadDashboardProductSearch();
            return;
        }

        var editor = new ProductEditorWindow(_productRepository, latest);
        var saved = await editor.ShowDialog<bool>(this);
        if (saved)
        {
            RefreshAllData();
            ReloadDashboardProductSearch();
        }
    }
}
