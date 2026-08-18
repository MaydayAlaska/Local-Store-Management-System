using Avalonia.Controls;
using Avalonia.Input;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow : Window
{
    private const int ScannerModeOpenProduct = 0;
    private const int ScannerModeIncoming = 1;
    private const int ScannerModeOutgoing = 2;

    private readonly ProductRepository _productRepository = new();
    private readonly StockMovementRepository _stockMovementRepository = new();

    public MainWindow()
    {
        InitializeComponent();
        ApplySavedSettings();

        DatabasePathText.Text = $"Database: {AppPaths.DatabasePath}";
        Opened += (_, _) =>
        {
            RefreshDashboardCounters();
            BarcodeInput.Focus();
        };
    }

    private void DashboardButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowDashboard();

    private void ProductsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowProducts();

    private void WarehouseButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowWarehouse();

    private void MovementsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowMovements();

    private async void NewProductButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var editor = new ProductEditorWindow(_productRepository, null);
        var saved = await editor.ShowDialog<bool>(this);
        if (saved)
        {
            ReloadProducts();
            RefreshDashboardCounters();
        }
    }

    private async void EditProductButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (ProductsList.SelectedItem is not Product product)
        {
            return;
        }

        var latest = _productRepository.GetById(product.Id);
        if (latest is null)
        {
            ReloadProducts();
            return;
        }

        var editor = new ProductEditorWindow(_productRepository, latest);
        var saved = await editor.ShowDialog<bool>(this);
        if (saved)
        {
            ReloadProducts();
            RefreshDashboardCounters();
        }
    }

    private void ProductSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e) => ReloadProducts();

    private void WarehouseSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e) => ReloadWarehouseProducts();

    private void MovementSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e) => ReloadMovements();

    private async void IncomingButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await OpenMovementEditorAsync(StockMovementKind.Incoming);

    private async void OutgoingButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await OpenMovementEditorAsync(StockMovementKind.Outgoing);

    private async void AdjustmentButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await OpenMovementEditorAsync(StockMovementKind.Adjustment);

    private async void WarehouseProductsList_OnDoubleTapped(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await OpenMovementEditorAsync(StockMovementKind.Incoming);

    private async Task OpenMovementEditorAsync(StockMovementKind kind)
    {
        if (WarehouseProductsList.SelectedItem is not Product product)
        {
            return;
        }

        var latest = _productRepository.GetById(product.Id);
        if (latest is null)
        {
            ReloadWarehouseProducts();
            return;
        }

        var editor = new StockMovementWindow(_stockMovementRepository, latest, kind);
        var saved = await editor.ShowDialog<bool>(this);
        if (!saved)
        {
            return;
        }

        RefreshAllData();
    }

    private async void BarcodeInput_OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter)
        {
            return;
        }

        var code = BarcodeInput.Text?.Trim();
        BarcodeInput.Clear();
        e.Handled = true;

        if (string.IsNullOrWhiteSpace(code))
        {
            BarcodeInput.Focus();
            return;
        }

        try
        {
            await HandleScannerCodeAsync(code);
        }
        finally
        {
            BarcodeInput.Focus();
        }
    }

    private async Task HandleScannerCodeAsync(string code)
    {
        var product = _productRepository.FindByBarcode(code);
        var scannerMode = ScannerModeInput.SelectedIndex;

        if (product is null)
        {
            await HandleUnknownScannerCodeAsync(code, scannerMode);
            return;
        }

        switch (scannerMode)
        {
            case ScannerModeIncoming:
                ApplyQuickMovement(product, StockMovementKind.Incoming);
                break;

            case ScannerModeOutgoing:
                ApplyQuickMovement(product, StockMovementKind.Outgoing);
                break;

            default:
                await OpenProductFromScannerAsync(product);
                break;
        }
    }

    private async Task HandleUnknownScannerCodeAsync(string code, int scannerMode)
    {
        LastScanText.Text = $"Codice non presente: {code}. Compila la nuova scheda prodotto oppure annulla.";

        var editor = new ProductEditorWindow(_productRepository, null, code);
        var saved = await editor.ShowDialog<bool>(this);
        if (!saved)
        {
            LastScanText.Text = $"Creazione annullata per il codice {code}.";
            return;
        }

        RefreshAllData();

        var createdProduct = _productRepository.FindByBarcode(code);
        if (createdProduct is null)
        {
            LastScanText.Text = $"Prodotto salvato, ma il codice {code} non è più associato alla scheda.";
            return;
        }

        if (scannerMode == ScannerModeIncoming)
        {
            ApplyQuickMovement(createdProduct, StockMovementKind.Incoming);
            return;
        }

        if (scannerMode == ScannerModeOutgoing)
        {
            LastScanText.Text = $"Creato {createdProduct.Name}. Scarico rapido non eseguito: la giacenza iniziale è 0.";
            return;
        }

        LastScanText.Text = $"Creato {createdProduct.Name} — codice {code}.";
    }

    private async Task OpenProductFromScannerAsync(Product product)
    {
        LastScanText.Text = $"Trovato {product.Name} — giacenza {product.StockQuantity}.";

        var latest = _productRepository.GetById(product.Id);
        if (latest is null)
        {
            LastScanText.Text = $"Il prodotto associato al codice non è più disponibile.";
            return;
        }

        var editor = new ProductEditorWindow(_productRepository, latest);
        var saved = await editor.ShowDialog<bool>(this);
        if (saved)
        {
            RefreshAllData();
            var updated = _productRepository.GetById(product.Id);
            if (updated is not null)
            {
                LastScanText.Text = $"Scheda aggiornata: {updated.Name} — giacenza {updated.StockQuantity}.";
            }
        }
    }

    private void ApplyQuickMovement(Product product, StockMovementKind kind)
    {
        try
        {
            var note = kind == StockMovementKind.Incoming
                ? "Carico rapido da scanner"
                : "Scarico rapido da scanner";

            _stockMovementRepository.AddMovement(product.Id, kind, 1, note);
            RefreshAllData();

            var updated = _productRepository.GetById(product.Id);
            var stock = updated?.StockQuantity ?? _stockMovementRepository.GetCurrentStock(product.Id);
            var prefix = kind == StockMovementKind.Incoming ? "+1 carico" : "-1 scarico";
            LastScanText.Text = $"{prefix}: {product.Name} — giacenza {stock}.";
        }
        catch (Exception ex)
        {
            LastScanText.Text = $"Operazione non eseguita per {product.Name}: {ex.Message}";
        }
    }

    private void ShowDashboard()
    {
        HideAllPanels();
        DashboardPanel.IsVisible = true;
        PageTitle.Text = "Dashboard";
        PageSubtitle.Text = "Applicazione desktop Windows + Linux";
        RefreshDashboardCounters();
        BarcodeInput.Focus();
    }

    private void ShowProducts()
    {
        HideAllPanels();
        ProductsPanel.IsVisible = true;
        PageTitle.Text = "Prodotti";
        PageSubtitle.Text = "Anagrafica articoli, prezzi e attributi";
        ReloadProducts();
        ProductSearchInput.Focus();
    }

    private void ShowWarehouse()
    {
        HideAllPanels();
        WarehousePanel.IsVisible = true;
        PageTitle.Text = "Magazzino";
        PageSubtitle.Text = "Carico, scarico e rettifica delle giacenze";
        ReloadWarehouseProducts();
        WarehouseSearchInput.Focus();
    }

    private void ShowMovements()
    {
        HideAllPanels();
        MovementsPanel.IsVisible = true;
        PageTitle.Text = "Movimenti";
        PageSubtitle.Text = "Storico cronologico di tutte le variazioni di magazzino";
        ReloadMovements();
        MovementSearchInput.Focus();
    }

    private void HideAllPanels()
    {
        DashboardPanel.IsVisible = false;
        ProductsPanel.IsVisible = false;
        WarehousePanel.IsVisible = false;
        MovementsPanel.IsVisible = false;
    }

    private void ReloadProducts()
    {
        var products = _productRepository.Search(ProductSearchInput.Text);
        ProductsList.ItemsSource = products;
        EmptyProductsPanel.IsVisible = products.Count == 0;
    }

    private void ReloadWarehouseProducts()
    {
        var products = _productRepository.Search(WarehouseSearchInput.Text);
        WarehouseProductsList.ItemsSource = products;
        EmptyWarehouseText.IsVisible = products.Count == 0;

        var exactQuery = WarehouseSearchInput.Text?.Trim();
        if (!string.IsNullOrWhiteSpace(exactQuery))
        {
            var exactProduct = _productRepository.FindByBarcode(exactQuery);
            if (exactProduct is not null)
            {
                WarehouseProductsList.SelectedItem = products.FirstOrDefault(item => item.Id == exactProduct.Id);
            }
        }
    }

    private void ReloadMovements()
    {
        var movements = _stockMovementRepository.Search(MovementSearchInput.Text);
        MovementsList.ItemsSource = movements;
        EmptyMovementsText.IsVisible = movements.Count == 0;
    }

    private void RefreshAllData()
    {
        ReloadProducts();
        ReloadWarehouseProducts();
        ReloadMovements();
        RefreshDashboardCounters();
    }

    private void RefreshDashboardCounters()
    {
        ProductsCountText.Text = _productRepository.Count().ToString();
        TotalStockText.Text = _stockMovementRepository.GetTotalStock().ToString();
    }
}
