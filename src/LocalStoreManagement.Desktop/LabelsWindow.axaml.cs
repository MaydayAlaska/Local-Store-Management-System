using System.Globalization;
using Avalonia.Controls;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;
using LocalStoreManagement.Desktop.Services;

namespace LocalStoreManagement.Desktop;

public partial class LabelsWindow : Window
{
    private readonly ProductRepository _productRepository;
    private readonly ILabelPrinter _labelPrinter;
    private bool _previewBarcodeValid;

    public LabelsWindow()
        : this(new ProductRepository(), LabelPrinterFactory.Create())
    {
    }

    public LabelsWindow(ProductRepository productRepository)
        : this(productRepository, LabelPrinterFactory.Create())
    {
    }

    internal LabelsWindow(ProductRepository productRepository, ILabelPrinter labelPrinter)
    {
        _productRepository = productRepository;
        _labelPrinter = labelPrinter;

        InitializeComponent();

        BackendText.Text = _labelPrinter.BackendDescription;
        DriverHelpText.Text = OperatingSystem.IsWindows()
            ? "Windows: la dimensione fisica della pagina viene presa dal driver. Configura nel driver della stampante la stessa misura scelta qui."
            : "Linux: il gestionale invia un PDF alla coda CUPS. Configura la coda della stampante con la stessa misura dell'etichetta.";

        Opened += LabelsWindow_OnOpened;
    }

    private async void LabelsWindow_OnOpened(object? sender, EventArgs e)
    {
        ReloadProducts();
        UpdatePreviewSize();
        await RefreshPrintersAsync();
        LabelSearchInput.Focus();
    }

    private void LabelSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e)
        => ReloadProducts();

    private void ProductsList_OnSelectionChanged(object? sender, SelectionChangedEventArgs e)
        => UpdatePreview();

    private void PrinterInput_OnSelectionChanged(object? sender, SelectionChangedEventArgs e)
        => UpdatePrintButtonState();

    private async void RefreshPrintersButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await RefreshPrintersAsync();

    private void LabelSizeInput_OnValueChanged(object? sender, NumericUpDownValueChangedEventArgs e)
        => UpdatePreviewSize();

    private async void PrintButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (ProductsList.SelectedItem is not Product product)
        {
            SetStatus("Seleziona un prodotto da etichettare.");
            return;
        }

        if (PrinterInput.SelectedItem is not string printerName || string.IsNullOrWhiteSpace(printerName))
        {
            SetStatus("Seleziona una stampante.");
            return;
        }

        var barcode = GetPrintableBarcode(product);
        if (string.IsNullOrWhiteSpace(barcode))
        {
            SetStatus("Il prodotto non ha né barcode né SKU utilizzabile.");
            return;
        }

        var copies = decimal.ToInt32(CopiesInput.Value ?? 1m);
        var width = decimal.ToDouble(WidthInput.Value ?? 50m);
        var height = decimal.ToDouble(HeightInput.Value ?? 30m);
        var price = product.SalePriceCents.HasValue
            ? product.SalePriceCents.Value / 100m
            : (decimal?)null;

        var request = new LabelPrintRequest(
            printerName,
            product.Name,
            barcode,
            product.Sku,
            product.Variant,
            product.Size,
            price,
            copies,
            width,
            height);

        PrintButton.IsEnabled = false;
        SetStatus($"Invio di {copies} {(copies == 1 ? "etichetta" : "etichette")} a {printerName}...");

        try
        {
            await _labelPrinter.PrintAsync(request);
            SetStatus($"Stampa inviata a {printerName}: {copies} {(copies == 1 ? "copia" : "copie")}.");
        }
        catch (Exception ex)
        {
            SetStatus($"Stampa non riuscita: {ex.Message}");
        }
        finally
        {
            UpdatePrintButtonState();
        }
    }

    private void CloseButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => Close();

    private void ReloadProducts()
    {
        var selectedId = (ProductsList.SelectedItem as Product)?.Id;
        var products = _productRepository.Search(LabelSearchInput.Text);

        ProductsList.ItemsSource = products;
        EmptyProductsText.IsVisible = products.Count == 0;

        Product? selected = null;
        if (selectedId.HasValue)
        {
            selected = products.FirstOrDefault(product => product.Id == selectedId.Value);
        }

        ProductsList.SelectedItem = selected ?? products.FirstOrDefault();
        UpdatePreview();
    }

    private void UpdatePreview()
    {
        _previewBarcodeValid = false;

        if (ProductsList.SelectedItem is not Product product)
        {
            PreviewProductName.Text = "Nessun prodotto selezionato";
            PreviewDetails.Text = string.Empty;
            PreviewBarcodeText.Text = string.Empty;
            PreviewSku.Text = string.Empty;
            PreviewPrice.Text = string.Empty;
            BarcodePreview.Value = null;
            SymbologyText.Text = string.Empty;
            SetStatus("Seleziona un prodotto da etichettare.");
            UpdatePrintButtonState();
            return;
        }

        var details = string.Join(
            " • ",
            new[] { product.Brand, product.Category, product.Variant, product.Size }
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Select(value => value!.Trim()));

        var barcode = GetPrintableBarcode(product);

        PreviewProductName.Text = product.Name;
        PreviewDetails.Text = details;
        PreviewSku.Text = product.Sku;
        PreviewPrice.Text = product.SalePriceCents.HasValue
            ? (product.SalePriceCents.Value / 100m).ToString("C2", CultureInfo.GetCultureInfo("it-IT"))
            : string.Empty;
        PreviewBarcodeText.Text = barcode ?? string.Empty;
        BarcodePreview.Value = barcode;

        if (string.IsNullOrWhiteSpace(barcode))
        {
            SymbologyText.Text = "Barcode non disponibile";
            SetStatus("Il prodotto non ha un barcode stampabile.");
            UpdatePrintButtonState();
            return;
        }

        try
        {
            var pattern = BarcodeEncoder.Encode(barcode);
            SymbologyText.Text = $"{pattern.Symbology} • {pattern.DisplayText}";
            _previewBarcodeValid = true;
            SetStatus(PrinterInput.SelectedItem is string
                ? "Etichetta pronta per la stampa."
                : "Etichetta pronta. Seleziona una stampante.");
        }
        catch (Exception ex)
        {
            SymbologyText.Text = "Barcode non valido";
            SetStatus(ex.Message);
        }

        UpdatePrintButtonState();
    }

    private async Task RefreshPrintersAsync()
    {
        var previousPrinter = PrinterInput.SelectedItem as string;
        PrinterInput.IsEnabled = false;
        SetStatus("Ricerca delle stampanti installate...");

        try
        {
            var printers = await _labelPrinter.GetPrintersAsync();
            PrinterInput.ItemsSource = printers;

            if (printers.Count == 0)
            {
                PrinterInput.SelectedItem = null;
                SetStatus(OperatingSystem.IsWindows()
                    ? "Nessuna stampante rilevata. Installa il driver della ApiX110/BIXOLON e riprova."
                    : "Nessuna stampante CUPS rilevata. Configura CUPS e il driver BIXOLON, quindi riprova.");
                return;
            }

            var selected = !string.IsNullOrWhiteSpace(previousPrinter)
                ? printers.FirstOrDefault(name => string.Equals(name, previousPrinter, StringComparison.OrdinalIgnoreCase))
                : null;

            PrinterInput.SelectedItem = selected ?? printers[0];
            SetStatus(_previewBarcodeValid
                ? "Etichetta pronta per la stampa."
                : "Stampante rilevata. Seleziona un prodotto con barcode valido.");
        }
        catch (Exception ex)
        {
            PrinterInput.ItemsSource = Array.Empty<string>();
            PrinterInput.SelectedItem = null;
            SetStatus($"Impossibile leggere le stampanti: {ex.Message}");
        }
        finally
        {
            PrinterInput.IsEnabled = true;
            UpdatePrintButtonState();
        }
    }

    private void UpdatePreviewSize()
    {
        if (LabelPreviewContainer is null || WidthInput is null || HeightInput is null)
        {
            return;
        }

        var widthMm = decimal.ToDouble(WidthInput.Value ?? 50m);
        var heightMm = decimal.ToDouble(HeightInput.Value ?? 30m);

        if (widthMm <= 0 || heightMm <= 0)
        {
            return;
        }

        const double maximumWidth = 430;
        const double maximumHeight = 285;

        var previewWidth = maximumWidth;
        var previewHeight = previewWidth * heightMm / widthMm;

        if (previewHeight > maximumHeight)
        {
            previewHeight = maximumHeight;
            previewWidth = previewHeight * widthMm / heightMm;
        }

        LabelPreviewContainer.Width = Math.Max(180, previewWidth);
        LabelPreviewContainer.Height = Math.Max(120, previewHeight);
    }

    private void UpdatePrintButtonState()
    {
        PrintButton.IsEnabled =
            _previewBarcodeValid &&
            ProductsList.SelectedItem is Product &&
            PrinterInput.SelectedItem is string &&
            PrinterInput.IsEnabled;
    }

    private static string? GetPrintableBarcode(Product product)
        => !string.IsNullOrWhiteSpace(product.Barcode)
            ? product.Barcode!.Trim()
            : !string.IsNullOrWhiteSpace(product.Sku)
                ? product.Sku.Trim()
                : null;

    private void SetStatus(string message)
    {
        StatusText.Text = message;
    }
}
