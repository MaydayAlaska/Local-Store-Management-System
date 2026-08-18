using System.Globalization;
using Avalonia.Controls;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class ProductVariantEditorWindow : Window
{
    private readonly ProductRepository _repository;
    private readonly ProductVariantDraft _draft;
    private readonly IReadOnlyList<ProductVariantDraft> _otherVariants;
    private readonly string _productName;

    public ProductVariantEditorWindow()
        : this(
            new ProductRepository(),
            "Prodotto",
            new ProductVariantDraft(null, string.Empty, null, null, null, null, true, Array.Empty<string>()),
            Array.Empty<ProductVariantDraft>())
    {
    }

    public ProductVariantEditorWindow(
        ProductRepository repository,
        string productName,
        ProductVariantDraft draft,
        IReadOnlyList<ProductVariantDraft> otherVariants)
    {
        _repository = repository;
        _draft = draft;
        _otherVariants = otherVariants;
        _productName = string.IsNullOrWhiteSpace(productName) ? "Prodotto" : productName.Trim();

        InitializeComponent();
        EditorTitle.Text = draft.Id.HasValue ? "Modifica variante" : "Nuova variante";
        ProductNameText.Text = _productName;
        SkuInput.Text = string.IsNullOrWhiteSpace(draft.Sku) ? _repository.GenerateSku() : draft.Sku;
        VariantInput.Text = draft.Variant;
        SizeInput.Text = draft.Size;
        BarcodesInput.Text = string.Join(Environment.NewLine, draft.Barcodes);
        PurchasePriceInput.Text = FormatEditablePrice(draft.PurchasePriceCents);
        SalePriceInput.Text = FormatEditablePrice(draft.SalePriceCents);
        IsActiveInput.IsChecked = draft.IsActive;
        StockText.Text = draft.Id.HasValue ? $"Giacenza: {draft.StockQuantity}" : "Nuova variante";
        Opened += (_, _) => SkuInput.Focus();
    }

    private void GenerateSkuButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        SkuInput.Text = _repository.GenerateSku();
        SkuInput.Focus();
        SkuInput.CaretIndex = SkuInput.Text?.Length ?? 0;
    }

    private void SaveButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        var sku = SkuInput.Text?.Trim() ?? string.Empty;
        if (sku.Length == 0)
        {
            ShowError("Il codice interno / SKU della variante è obbligatorio.");
            SkuInput.Focus();
            return;
        }

        if (!TryParsePrice(PurchasePriceInput.Text, out var purchasePriceCents))
        {
            ShowError("Il prezzo di acquisto non è valido.");
            PurchasePriceInput.Focus();
            return;
        }
        if (!TryParsePrice(SalePriceInput.Text, out var salePriceCents))
        {
            ShowError("Il prezzo di vendita non è valido.");
            SalePriceInput.Focus();
            return;
        }

        var siblingSku = _otherVariants.FirstOrDefault(item => string.Equals(item.Sku.Trim(), sku, StringComparison.OrdinalIgnoreCase));
        if (siblingSku is not null)
        {
            ShowError($"Lo SKU «{sku}» è già utilizzato da {_productName} — {siblingSku.VariantDisplay}.");
            SkuInput.Focus();
            return;
        }

        var databaseSkuOwner = _repository.FindSkuOwner(sku, _draft.Id);
        if (databaseSkuOwner is not null)
        {
            ShowError($"Lo SKU «{sku}» è già utilizzato da {databaseSkuOwner.DisplayName}.");
            SkuInput.Focus();
            return;
        }

        var barcodes = ParseBarcodes(BarcodesInput.Text);
        foreach (var barcode in barcodes)
        {
            var siblingOwner = _otherVariants.FirstOrDefault(item => item.Barcodes.Contains(barcode, StringComparer.Ordinal));
            if (siblingOwner is not null)
            {
                ShowError($"Il barcode «{barcode}» è già utilizzato da {_productName} — {siblingOwner.VariantDisplay} (SKU {siblingOwner.Sku}).");
                BarcodesInput.Focus();
                return;
            }

            var databaseOwner = _repository.FindBarcodeOwner(barcode, _draft.Id);
            if (databaseOwner is not null)
            {
                ShowError($"Il barcode «{barcode}» è già utilizzato da {databaseOwner.DisplayName}.");
                BarcodesInput.Focus();
                return;
            }
        }

        Close(new ProductVariantDraft(
            _draft.Id,
            sku,
            NormalizeOptional(VariantInput.Text),
            NormalizeOptional(SizeInput.Text),
            purchasePriceCents,
            salePriceCents,
            IsActiveInput.IsChecked ?? false,
            barcodes,
            _draft.StockQuantity));
    }

    private void CancelButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => Close((ProductVariantDraft?)null);

    private static IReadOnlyList<string> ParseBarcodes(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return Array.Empty<string>();
        return text
            .Split(new[] { "\r\n", "\n", ";", "," }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(value => value.Length > 0)
            .Distinct(StringComparer.Ordinal)
            .ToList();
    }

    private static string? NormalizeOptional(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static bool TryParsePrice(string? text, out long? cents)
    {
        cents = null;
        if (string.IsNullOrWhiteSpace(text)) return true;
        var value = text.Trim();
        if (!decimal.TryParse(value, NumberStyles.Number, CultureInfo.CurrentCulture, out var amount)
            && !decimal.TryParse(value.Replace(',', '.'), NumberStyles.Number, CultureInfo.InvariantCulture, out amount))
            return false;
        if (amount < 0) return false;
        cents = (long)Math.Round(amount * 100m, 0, MidpointRounding.AwayFromZero);
        return true;
    }

    private static string? FormatEditablePrice(long? cents)
        => cents.HasValue ? (cents.Value / 100m).ToString("0.00", CultureInfo.CurrentCulture) : null;

    private void ShowError(string message)
    {
        ErrorText.Text = message;
        ErrorPanel.IsVisible = true;
    }

    private void HideError()
    {
        ErrorText.Text = string.Empty;
        ErrorPanel.IsVisible = false;
    }
}
