using Avalonia.Controls;
using Avalonia.VisualTree;

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

        _secondaryNavigationAttached = true;
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
