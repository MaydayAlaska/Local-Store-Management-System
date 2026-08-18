using Avalonia.Controls;
using LocalStoreManagement.Desktop.Data;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private BrandsView? _brandsView;
    private CategoriesView? _categoriesView;
    private LabelsView? _labelsView;
    private ExportView? _exportView;

    private void BrandsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowBrands();

    private void ShowBrands()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(BrandsNavButton);
        EnsureBrandsView();
        _brandsView!.Reload();
        _brandsView.IsVisible = true;
        PageTitle.Text = "Marche";
        PageSubtitle.Text = "Crea, rinomina ed elimina le marche usate dai prodotti";
        _brandsView.FocusPrimaryField();
    }

    private void EnsureBrandsView()
    {
        if (_brandsView is not null) return;
        if (DashboardPanel.Parent is not Grid contentGrid) throw new InvalidOperationException("Impossibile inizializzare il pannello Marche.");
        _brandsView = new BrandsView(new BrandRepository()) { IsVisible = false };
        _brandsView.BrandsChanged += (_, _) => RefreshAllData();
        contentGrid.Children.Add(_brandsView);
    }

    private void HideBrandsView()
    {
        if (_brandsView is not null) _brandsView.IsVisible = false;
    }

    private void CategoriesButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowCategories();

    private void ShowCategories()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(CategoriesNavButton);
        EnsureCategoriesView();
        _categoriesView!.Reload();
        _categoriesView.IsVisible = true;
        PageTitle.Text = "Categorie";
        PageSubtitle.Text = "Crea, rinomina ed elimina le categorie usate dai prodotti";
        _categoriesView.FocusPrimaryField();
    }

    private void EnsureCategoriesView()
    {
        if (_categoriesView is not null) return;
        if (DashboardPanel.Parent is not Grid contentGrid) throw new InvalidOperationException("Impossibile inizializzare il pannello Categorie.");
        _categoriesView = new CategoriesView(new CategoryRepository()) { IsVisible = false };
        _categoriesView.CategoriesChanged += (_, _) => RefreshAllData();
        contentGrid.Children.Add(_categoriesView);
    }

    private void HideCategoriesView()
    {
        if (_categoriesView is not null) _categoriesView.IsVisible = false;
    }

    private async void LabelsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await ShowLabelsAsync();

    private async Task ShowLabelsAsync()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(LabelsNavButton);
        EnsureLabelsView();
        _labelsView!.IsVisible = true;
        PageTitle.Text = "Etichette";
        PageSubtitle.Text = "Anteprima barcode e stampa tramite la coda di sistema Windows/Linux";
        await _labelsView.ReloadAsync();
        _labelsView.FocusPrimaryField();
    }

    private void EnsureLabelsView()
    {
        if (_labelsView is not null) return;
        if (DashboardPanel.Parent is not Grid contentGrid) throw new InvalidOperationException("Impossibile inizializzare il pannello Etichette.");
        _labelsView = new LabelsView(_productRepository) { IsVisible = false };
        contentGrid.Children.Add(_labelsView);
    }

    private void HideLabelsView()
    {
        if (_labelsView is not null) _labelsView.IsVisible = false;
    }

    private void ExportButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => ShowExport();

    private void ShowExport()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(ExportNavButton);
        EnsureExportView();
        _exportView!.Reload();
        _exportView.IsVisible = true;
        PageTitle.Text = "Esportazione";
        PageSubtitle.Text = "Backup ed esportazione dell'inventario in Excel o PDF";
    }

    private void EnsureExportView()
    {
        if (_exportView is not null) return;
        if (DashboardPanel.Parent is not Grid contentGrid) throw new InvalidOperationException("Impossibile inizializzare il pannello Esportazione.");
        _exportView = new ExportView(_productRepository, _appSettingsService) { IsVisible = false };
        contentGrid.Children.Add(_exportView);
    }

    private void HideExportView()
    {
        if (_exportView is not null) _exportView.IsVisible = false;
    }
}
