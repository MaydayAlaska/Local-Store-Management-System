using Avalonia.Controls;
using Avalonia.Input;
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
    private long? _dashboardSelectedProductId;

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
        HideLabelsView();
        HideExportView();
    }

    private void DashboardSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e)
        => ReloadDashboardSearch();

    private void DashboardSearchInput_OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter)
        {
            return;
        }

        e.Handled = true;
        var query = DashboardSearchInput.Text?.Trim();
        if (string.IsNullOrWhiteSpace(query))
        {
            DashboardSearchInput.Focus();
            return;
        }

        var exact = _productRepository.FindByBarcode(query);
        if (exact is not null)
        {
            SelectDashboardProduct(exact);
            PrepareDashboardSearchForNextScan();
            DashboardSearchStatusText.Text = $"Prodotto trovato: {exact.Name}. Pronto per la prossima scansione.";
            return;
        }

        if (DashboardProductsList.SelectedItem is Product selected)
        {
            ShowDashboardProduct(selected);
            PrepareDashboardSearchForNextScan();
            DashboardSearchStatusText.Text = $"Prodotto selezionato: {selected.Name}. Pronto per la prossima ricerca o scansione.";
            return;
        }

        PrepareDashboardSearchForNextScan();
        DashboardSearchStatusText.Text = $"Nessun prodotto trovato per «{query}». Pronto per una nuova scansione.";
    }

    private void PrepareDashboardSearchForNextScan()
    {
        DashboardSearchInput.Clear();
        DashboardSearchInput.Focus();
    }

    private void DashboardProductsList_OnSelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (DashboardProductsList.SelectedItem is Product product)
        {
            ShowDashboardProduct(product);
        }
    }

    private async void DashboardProductsList_OnDoubleTapped(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await OpenDashboardSelectedProductAsync();

    private async void DashboardEditProductButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await OpenDashboardSelectedProductAsync();

    private void DashboardIncomingButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => ApplyDashboardMovement(StockMovementKind.Incoming);

    private void DashboardOutgoingButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => ApplyDashboardMovement(StockMovementKind.Outgoing);

    private void ReloadDashboardSearch()
    {
        var query = DashboardSearchInput.Text?.Trim();
        if (string.IsNullOrWhiteSpace(query))
        {
            DashboardProductsList.ItemsSource = null;
            DashboardSearchStatusText.Text = "Scansiona un codice oppure cerca un prodotto per nome, SKU o barcode.";

            if (_dashboardSelectedProductId.HasValue)
            {
                var latest = _productRepository.GetById(_dashboardSelectedProductId.Value);
                if (latest is not null)
                {
                    ShowDashboardProduct(latest);
                    return;
                }
            }

            DashboardProductDetailsPanel.IsVisible = false;
            return;
        }

        var products = _productRepository.Search(query).Take(20).ToList();
        DashboardProductsList.ItemsSource = products;

        var exact = _productRepository.FindByBarcode(query);
        Product? selected = null;
        if (exact is not null)
        {
            selected = products.FirstOrDefault(product => product.Id == exact.Id) ?? exact;
        }
        else if (_dashboardSelectedProductId.HasValue)
        {
            selected = products.FirstOrDefault(product => product.Id == _dashboardSelectedProductId.Value);
        }

        if (selected is null && products.Count == 1)
        {
            selected = products[0];
        }

        DashboardProductsList.SelectedItem = selected;
        if (selected is not null)
        {
            ShowDashboardProduct(selected);
        }
        else
        {
            _dashboardSelectedProductId = null;
            DashboardProductDetailsPanel.IsVisible = false;
        }

        DashboardSearchStatusText.Text = products.Count switch
        {
            0 => "Nessun prodotto trovato.",
            1 => "1 prodotto trovato.",
            _ => $"{products.Count} prodotti trovati. Seleziona quello desiderato."
        };
    }

    private void SelectDashboardProduct(Product product)
    {
        var items = (DashboardProductsList.ItemsSource as IEnumerable<Product>)?.ToList() ?? new List<Product>();
        var matching = items.FirstOrDefault(item => item.Id == product.Id);
        if (matching is null)
        {
            DashboardProductsList.ItemsSource = new[] { product };
            matching = product;
        }

        DashboardProductsList.SelectedItem = matching;
        ShowDashboardProduct(product);
    }

    private void ShowDashboardProduct(Product product)
    {
        var latest = _productRepository.GetById(product.Id) ?? product;
        _dashboardSelectedProductId = latest.Id;

        DashboardProductNameText.Text = latest.Name;
        DashboardProductCodeSummaryText.Text = string.IsNullOrWhiteSpace(latest.Barcode)
            ? latest.Sku
            : $"{latest.Sku}  •  {latest.Barcode}";
        DashboardStockText.Text = latest.StockQuantity.ToString();
        DashboardStatusText.Text = latest.StatusDisplay;
        DashboardBrandText.Text = DisplayValue(latest.Brand);
        DashboardCategoryText.Text = DisplayValue(latest.Category);
        DashboardSkuText.Text = latest.Sku;
        DashboardBarcodeText.Text = DisplayValue(latest.Barcode);
        DashboardVariantText.Text = DisplayValue(latest.Variant);
        DashboardSizeText.Text = DisplayValue(latest.Size);
        DashboardPurchasePriceText.Text = latest.PurchasePriceDisplay;
        DashboardSalePriceText.Text = latest.SalePriceDisplay;
        DashboardProductIdText.Text = latest.Id.ToString();
        DashboardNotesText.Text = DisplayValue(latest.Notes);
        DashboardOutgoingButton.IsEnabled = latest.StockQuantity > 0;
        DashboardMovementStatusText.Text = string.Empty;
        DashboardProductDetailsPanel.IsVisible = true;
    }

    private void ApplyDashboardMovement(StockMovementKind kind)
    {
        if (!_dashboardSelectedProductId.HasValue)
        {
            return;
        }

        var product = _productRepository.GetById(_dashboardSelectedProductId.Value);
        if (product is null)
        {
            _dashboardSelectedProductId = null;
            DashboardProductDetailsPanel.IsVisible = false;
            DashboardSearchStatusText.Text = "Il prodotto selezionato non esiste più.";
            return;
        }

        try
        {
            var note = kind == StockMovementKind.Incoming
                ? "Carico rapido da Dashboard"
                : "Scarico rapido da Dashboard";
            _stockMovementRepository.AddMovement(product.Id, kind, 1, note);

            ReloadProducts();
            ReloadWarehouseProducts();
            ReloadMovements();
            RefreshDashboardCounters();

            var updated = _productRepository.GetById(product.Id);
            if (updated is not null)
            {
                ShowDashboardProduct(updated);
                DashboardMovementStatusText.Text = kind == StockMovementKind.Incoming
                    ? $"+1 registrato. Nuova giacenza: {updated.StockQuantity}."
                    : $"-1 registrato. Nuova giacenza: {updated.StockQuantity}.";
            }
        }
        catch (Exception ex)
        {
            DashboardMovementStatusText.Text = $"Movimento non eseguito: {ex.Message}";
        }
        finally
        {
            DashboardSearchInput.Focus();
        }
    }

    private async Task OpenDashboardSelectedProductAsync()
    {
        if (!_dashboardSelectedProductId.HasValue)
        {
            return;
        }

        var latest = _productRepository.GetById(_dashboardSelectedProductId.Value);
        if (latest is null)
        {
            _dashboardSelectedProductId = null;
            DashboardProductDetailsPanel.IsVisible = false;
            ReloadDashboardSearch();
            return;
        }

        var editor = new ProductEditorWindow(_productRepository, latest);
        var saved = await editor.ShowDialog<bool>(this);
        if (!saved)
        {
            return;
        }

        RefreshAllData();
        var updated = _productRepository.GetById(latest.Id);
        if (updated is not null)
        {
            ShowDashboardProduct(updated);
        }
    }

    private static string DisplayValue(string? value)
        => string.IsNullOrWhiteSpace(value) ? "—" : value.Trim();
}
