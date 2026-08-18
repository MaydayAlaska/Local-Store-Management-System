using Avalonia.Controls;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow : Window
{
    private readonly ProductRepository _productRepository = new();
    private readonly StockMovementRepository _stockMovementRepository = new();

    public MainWindow()
    {
        InitializeComponent();
        ApplySidebarPresentationTweaks();
        InitializeCustomTitleBar();
        ApplySavedSettings();

        DatabasePathText.Text = $"Database: {AppPaths.DatabasePath}";
        Opened += (_, _) =>
        {
            RefreshDashboardCounters();
            SetActiveNavigation(DashboardNavButton);
            DashboardSearchInput.Focus();
        };
    }

    private void ApplySidebarPresentationTweaks()
    {
        DashboardNavButton.Content = "Dashboard";
        ProductsNavButton.Content = "Prodotti";
        WarehouseNavButton.Content = "Magazzino";
        BrandsNavButton.Content = "Marche";
        CategoriesNavButton.Content = "Categorie";
        LabelsNavButton.Content = "Etichette";
        MovementsNavButton.Content = "Movimenti";
        ExportNavButton.Content = "Esportazione";

        if (SettingsNavButton.Parent is Grid footer)
        {
            foreach (var child in footer.Children)
            {
                if (!ReferenceEquals(child, SettingsNavButton))
                {
                    child.IsVisible = false;
                }
            }
        }
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
            ReloadDashboardSearch();
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
            ReloadDashboardSearch();
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

    private void ShowDashboard()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(DashboardNavButton);
        DashboardPanel.IsVisible = true;
        PageTitle.Text = "Dashboard";
        PageSubtitle.Text = "Ricerca, scansione e giacenza rapida";
        RefreshDashboardCounters();
        ReloadDashboardSearch();
        DashboardSearchInput.Focus();
    }

    private void ShowProducts()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(ProductsNavButton);
        ProductsPanel.IsVisible = true;
        PageTitle.Text = "Prodotti";
        PageSubtitle.Text = "Anagrafica articoli, prezzi e attributi";
        ReloadProducts();
        ProductSearchInput.Focus();
    }

    private void ShowWarehouse()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(WarehouseNavButton);
        WarehousePanel.IsVisible = true;
        PageTitle.Text = "Magazzino";
        PageSubtitle.Text = "Carico, scarico e rettifica delle giacenze";
        ReloadWarehouseProducts();
        WarehouseSearchInput.Focus();
    }

    private void ShowMovements()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(MovementsNavButton);
        MovementsPanel.IsVisible = true;
        PageTitle.Text = "Movimenti";
        PageSubtitle.Text = "Storico cronologico di tutte le variazioni di magazzino";
        ReloadMovements();
        MovementSearchInput.Focus();
    }

    private void SetActiveNavigation(Button activeButton)
    {
        var navigationButtons = new[]
        {
            DashboardNavButton,
            ProductsNavButton,
            WarehouseNavButton,
            BrandsNavButton,
            CategoriesNavButton,
            LabelsNavButton,
            MovementsNavButton,
            ExportNavButton,
            SettingsNavButton
        };

        foreach (var button in navigationButtons)
        {
            button.Classes.Remove("Selected");
        }

        if (!activeButton.Classes.Contains("Selected"))
        {
            activeButton.Classes.Add("Selected");
        }
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
        ReloadDashboardSearch();
    }

    private void RefreshDashboardCounters()
    {
        ProductsCountText.Text = _productRepository.Count().ToString();
        TotalStockText.Text = _stockMovementRepository.GetTotalStock().ToString();
    }
}
