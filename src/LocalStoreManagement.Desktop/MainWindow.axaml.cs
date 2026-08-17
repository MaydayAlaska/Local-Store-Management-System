using Avalonia.Controls;
using Avalonia.Input;
using LocalStoreManagement.Desktop.Infrastructure;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        DatabasePathText.Text = $"Database: {AppPaths.DatabasePath}";
        Opened += (_, _) => BarcodeInput.Focus();
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
}
