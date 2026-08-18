using Avalonia.Controls;
using Avalonia.VisualTree;
using LocalStoreManagement.Desktop.Data;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private bool _secondaryNavigationAttached;

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
        AttachSettingsHideToMainNavigation();
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
            }
        }

        var settingsButton = buttons.FirstOrDefault(button =>
            button.Content is string text
            && text.Contains("Impostazioni", StringComparison.Ordinal));
        if (settingsButton is not null)
        {
            settingsButton.Content = "⚙";
            settingsButton.Classes.Add("SidebarIcon");
            ToolTip.SetTip(settingsButton, "Impostazioni");
        }
    }

    private void AttachSettingsHideToMainNavigation()
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
                button.Click += (_, _) => HideSettingsView();
            }
        }
    }

    private async void CategoriesButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var window = new CategoriesWindow(new CategoryRepository());
        await window.ShowDialog(this);
        RefreshAllData();
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
