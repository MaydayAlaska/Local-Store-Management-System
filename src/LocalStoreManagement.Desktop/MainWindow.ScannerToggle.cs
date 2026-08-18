using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using Avalonia.VisualTree;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private bool _scannerDirectionButtonsAttached;
    private bool _scannerDirectionButtonsScheduled;

    protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
    {
        base.OnAttachedToVisualTree(e);

        if (_scannerDirectionButtonsScheduled)
        {
            return;
        }

        _scannerDirectionButtonsScheduled = true;

        // Non modificare la collezione Children mentre Avalonia sta ancora
        // percorrendo il visual tree durante l'attach. La sostituzione viene
        // eseguita al giro successivo del dispatcher UI.
        Dispatcher.UIThread.Post(AttachScannerDirectionButtons);
    }

    private void AttachScannerDirectionButtons()
    {
        if (_scannerDirectionButtonsAttached || ScannerModeInput.Parent is not StackPanel modePanel)
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

        // Il codice di gestione scanner usa ancora SelectedIndex internamente:
        // 1 = carico, 2 = scarico. L'interfaccia espone solo queste due azioni.
        ScannerModeInput.SelectedIndex = 1;

        var incomingButton = new ToggleButton
        {
            Content = "+1",
            IsChecked = true,
            MinWidth = 64,
            FontWeight = FontWeight.SemiBold
        };

        var outgoingButton = new ToggleButton
        {
            Content = "-1",
            IsChecked = false,
            MinWidth = 64,
            FontWeight = FontWeight.SemiBold
        };

        incomingButton.Click += (_, _) =>
        {
            incomingButton.IsChecked = true;
            outgoingButton.IsChecked = false;
            ScannerModeInput.SelectedIndex = 1;
            BarcodeInput.Focus();
        };

        outgoingButton.Click += (_, _) =>
        {
            incomingButton.IsChecked = false;
            outgoingButton.IsChecked = true;
            ScannerModeInput.SelectedIndex = 2;
            BarcodeInput.Focus();
        };

        ToolTip.SetTip(incomingButton, "+1 carica un pezzo");
        ToolTip.SetTip(outgoingButton, "-1 scarica un pezzo");

        var buttonPanel = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            HorizontalAlignment = HorizontalAlignment.Left
        };
        buttonPanel.Children.Add(incomingButton);
        buttonPanel.Children.Add(outgoingButton);

        modePanel.Children.RemoveAt(comboIndex);
        modePanel.Children.Insert(comboIndex, buttonPanel);
        _scannerDirectionButtonsAttached = true;
    }
}
