using Avalonia.Controls;
using Avalonia.Input;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow : Window
{
    private readonly ProductRepository _productRepository = new();

    public MainWindow()
    {
        InitializeComponent();

        DatabasePathText.Text = $"Database: {AppPaths.DatabasePath}";
        Opened += (_, _) =>
        {
            RefreshProductCount();
            BarcodeInput.Focus();
        };
    }

    private void DashboardButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        ShowDashboard();
    }

    private void ProductsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        ShowProducts();
    }

    private async void NewProductButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var editor = new ProductEditorWindow(_productRepository, null);
        var saved = await editor.ShowDialog<bool>(this);
        if (saved)
        {
            ReloadProducts();
            RefreshProductCount();
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
            RefreshProductCount();
        }
    }

    private void ProductSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e)
    {
        ReloadProducts();
    }

    private void BarcodeInput_OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter)
        {
            return;
        }

        var barcode = BarcodeInput.Text?.Trim();
        if (!string.IsNullOrWhiteSpace(barcode))
        {
            LastScanText.Text = $"Ultimo codice: {barcode}";
        }

        BarcodeInput.Clear();
        e.Handled = true;
    }

    private void ShowDashboard()
    {
        DashboardPanel.IsVisible = true;
        ProductsPanel.IsVisible = false;
        PageTitle.Text = "Dashboard";
        PageSubtitle.Text = "Applicazione desktop Windows + Linux";
        RefreshProductCount();
        BarcodeInput.Focus();
    }

    private void ShowProducts()
    {
        DashboardPanel.IsVisible = false;
        ProductsPanel.IsVisible = true;
        PageTitle.Text = "Prodotti";
        PageSubtitle.Text = "Anagrafica articoli, prezzi e attributi";
        ReloadProducts();
        ProductSearchInput.Focus();
    }

    private void ReloadProducts()
    {
        var products = _productRepository.Search(ProductSearchInput.Text);
        ProductsList.ItemsSource = products;
        EmptyProductsPanel.IsVisible = products.Count == 0;
    }

    private void RefreshProductCount()
    {
        ProductsCountText.Text = _productRepository.Count().ToString();
    }
}
