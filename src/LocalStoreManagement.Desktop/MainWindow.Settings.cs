using Avalonia.Controls;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private readonly AppSettingsService _appSettingsService = new();

    private void ApplySavedSettings()
    {
        var settings = _appSettingsService.Load();
        ShopNameText.Text = settings.ShopName;
        Title = settings.ShopName == AppSettings.Default.ShopName
            ? "Local Store Management System"
            : $"{settings.ShopName} - Local Store Management System";

        var iconPath = _appSettingsService.ResolveIconPath(settings);
        if (iconPath is null)
        {
            return;
        }

        try
        {
            Icon = new WindowIcon(iconPath);
        }
        catch
        {
            // Un'icona non valida non deve impedire l'avvio del gestionale.
        }
    }

    private async void SettingsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var settingsWindow = new SettingsWindow(_appSettingsService);
        var saved = await settingsWindow.ShowDialog<bool>(this);
        if (saved)
        {
            ApplySavedSettings();
        }
    }

    private void DashboardProductSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e)
    {
        ReloadDashboardProductSearch();
    }

    private async void DashboardOpenProductButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        await OpenDashboardSelectedProductAsync();
    }

    private async void DashboardProductsList_OnDoubleTapped(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        await OpenDashboardSelectedProductAsync();
    }

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
        if (DashboardProductsList.SelectedItem is not Product product)
        {
            return;
        }

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
