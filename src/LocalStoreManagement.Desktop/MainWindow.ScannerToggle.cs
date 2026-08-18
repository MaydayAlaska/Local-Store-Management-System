using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.VisualTree;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private bool _scannerDirectionSwitchAttached;

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);
        AttachScannerDirectionSwitch();
    }

    private void AttachScannerDirectionSwitch()
    {
        if (_scannerDirectionSwitchAttached || ScannerModeInput.Parent is not StackPanel modePanel)
        {
            return;
        }

        var comboIndex = modePanel.Children.IndexOf(ScannerModeInput);
        if (comboIndex < 0)
        {
            return;
        }

        var label = modePanel.Children
            .OfType<TextBlock>()
            .FirstOrDefault();
        if (label is not null)
        {
            label.Text = "Movimento";
        }

        // Il codice esistente usa ancora SelectedIndex internamente:
        // 1 = carico, 2 = scarico. Il vecchio modo 0 (apri prodotto)
        // non è più raggiungibile dall'interfaccia.
        ScannerModeInput.SelectedIndex = 1;

        var directionSwitch = new ToggleSwitch
        {
            OffContent = "+1",
            OnContent = "-1",
            IsChecked = false,
            HorizontalAlignment = HorizontalAlignment.Left,
            FontWeight = FontWeight.SemiBold
        };

        directionSwitch.IsCheckedChanged += (_, _) =>
        {
            ScannerModeInput.SelectedIndex = directionSwitch.IsChecked == true ? 2 : 1;
            BarcodeInput.Focus();
        };

        ToolTip.SetTip(directionSwitch, "+1 carica un pezzo · -1 scarica un pezzo");

        modePanel.Children.RemoveAt(comboIndex);
        modePanel.Children.Insert(comboIndex, directionSwitch);
        _scannerDirectionSwitchAttached = true;
    }
}
