using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.VisualTree;
using LocalStoreManagement.Desktop.Data;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private bool _secondaryNavigationAttached;
    private CategoriesView? _categoriesView;

    protected override void OnOpened(EventArgs e)
    {
        base.OnOpened(e);
        AttachSecondaryNavigation();
    }

    private void AttachSecondaryNavigation()
    {
        if (_secondaryNavigationAttached)
        {
            return;
        }

        var buttons = this
            .GetVisualDescendants()
            .OfType<Button>()
            .ToList();

        var labelsButton = buttons.FirstOrDefault(button =>
            string.Equals(button.Content as string, "Etichette", StringComparison.Ordinal));
        if (labelsButton is not null)
        {
            InsertCategoriesButton(labelsButton);
            labelsButton.IsEnabled = true;
            labelsButton.Click += LabelsButton_OnClick;
        }

        var exportButton = buttons.FirstOrDefault(button =>
            string.Equals(button.Content as string, "Esportazione", StringComparison.Ordinal));
        if (exportButton is not null)
        {
            exportButton.IsEnabled = true;
            exportButton.Click += ExportButton_OnClick;
        }

        ApplySidebarPresentation();
        AttachEmbeddedViewHideToMainNavigation();
        _secondaryNavigationAttached = true;
    }

    private void InsertCategoriesButton(Button labelsButton)
    {
        var navigationPanel = this
            .GetVisualDescendants()
            .OfType<StackPanel>()
            .FirstOrDefault(panel => panel.Children.Contains(labelsButton));

        if (navigationPanel is null
            || navigationPanel.Children.OfType<Button>().Any(button =>
                string.Equals(button.Content as string, "Categorie", StringComparison.Ordinal)))
        {
            return;
        }

        var index = navigationPanel.Children.IndexOf(labelsButton);
        var categoriesButton = new Button
        {
            Content = "Categorie"
        };
        categoriesButton.Classes.Add("SidebarNav");
        categoriesButton.Click += CategoriesButton_OnClick;
        navigationPanel.Children.Insert(index, categoriesButton);
    }

    private void ApplySidebarPresentation()
    {
        // Il pannello laterale mantiene il titolo con margine, mentre le voci di
        // navigazione possono usare tutta la larghezza disponibile per l'highlight.
        var sidebarBorder = ShopNameText
            .GetVisualAncestors()
            .OfType<Border>()
            .FirstOrDefault();
        if (sidebarBorder is not null)
        {
            sidebarBorder.Padding = new Thickness(0, 20);
        }

        if (ShopNameText.Parent is StackPanel shopHeader)
        {
            shopHeader.Margin = new Thickness(20, 0, 20, 0);
        }

        var navigationLabels = new HashSet<string>(StringComparer.Ordinal)
        {
            "Dashboard",
            "Prodotti",
            "Magazzino",
            "Categorie",
            "Etichette",
            "Movimenti",
            "Esportazione"
        };

        var buttons = this
            .GetVisualDescendants()
            .OfType<Button>()
            .ToList();

        foreach (var button in buttons)
        {
            if (button.Content is string text && navigationLabels.Contains(text))
            {
                button.Classes.Add("SidebarNav");
                // Valore locale: impedisce al tema chiaro di rendere scuro il testo
                // durante pointerover/pressed.
                button.Foreground = Brushes.White;
            }
        }

        var settingsButton = buttons.FirstOrDefault(button =>
            button.Content is string text
            && text.Contains("Impostazioni", StringComparison.Ordinal));
        if (settingsButton is not null)
        {
            settingsButton.Content = "⚙";
            settingsButton.Classes.Add("SidebarIcon");
            settingsButton.Foreground = Brushes.White;
            settingsButton.HorizontalAlignment = HorizontalAlignment.Right;
            settingsButton.Margin = new Thickness(0, 0, 20, 0);
            ToolTip.SetTip(settingsButton, "Impostazioni");
        }
    }

    private void AttachEmbeddedViewHideToMainNavigation()
    {
        var mainPages = new HashSet<string>(StringComparer.Ordinal)
        {
            "Dashboard",
            "Prodotti",
            "Magazzino",
            "Movimenti"
        };

        foreach (var button in this.GetVisualDescendants().OfType<Button>())
        {
            if (button.Content is string text && mainPages.Contains(text))
            {
                button.Click += (_, _) => HideEmbeddedViews();
            }
        }
    }

    private void CategoriesButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        ShowCategories();
    }

    private void ShowCategories()
    {
        HideEmbeddedViews();
        HideAllPanels();
        EnsureCategoriesView();

        _categoriesView!.Reload();
        _categoriesView.IsVisible = true;
        PageTitle.Text = "Categorie";
        PageSubtitle.Text = "Crea, rinomina ed elimina le categorie usate dai prodotti";
        _categoriesView.FocusPrimaryField();
    }

    private void EnsureCategoriesView()
    {
        if (_categoriesView is not null)
        {
            return;
        }

        if (DashboardPanel.Parent is not Grid contentGrid)
        {
            throw new InvalidOperationException("Impossibile inizializzare il pannello Categorie.");
        }

        _categoriesView = new CategoriesView(new CategoryRepository())
        {
            IsVisible = false
        };
        _categoriesView.CategoriesChanged += (_, _) => RefreshAllData();
        contentGrid.Children.Add(_categoriesView);
    }

    private void HideCategoriesView()
    {
        if (_categoriesView is not null)
        {
            _categoriesView.IsVisible = false;
        }
    }

    private async void LabelsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var window = new LabelsWindow(_productRepository);
        await window.ShowDialog(this);
    }

    private async void ExportButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var window = new ExportWindow(_productRepository, _appSettingsService);
        await window.ShowDialog(this);
    }
}
