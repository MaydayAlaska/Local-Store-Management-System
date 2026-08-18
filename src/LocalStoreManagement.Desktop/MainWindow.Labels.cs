using Avalonia;
using Avalonia.Controls;
using Avalonia.VisualTree;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private bool _labelsNavigationAttached;

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);

        if (_labelsNavigationAttached)
        {
            return;
        }

        var labelsButton = this
            .GetVisualDescendants()
            .OfType<Button>()
            .FirstOrDefault(button =>
                string.Equals(button.Content as string, "Etichette", StringComparison.Ordinal));

        if (labelsButton is null)
        {
            return;
        }

        labelsButton.IsEnabled = true;
        labelsButton.Click += LabelsButton_OnClick;
        _labelsNavigationAttached = true;
    }

    private async void LabelsButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var window = new LabelsWindow(_productRepository);
        await window.ShowDialog(this);
    }
}
