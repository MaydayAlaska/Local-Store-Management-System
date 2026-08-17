using System.Globalization;
using Avalonia.Controls;
using Avalonia.Input;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop;

public partial class ProductEditorWindow : Window
{
    private readonly ProductRepository _repository;
    private readonly long? _productId;
    private readonly string? _initialBarcode;

    public ProductEditorWindow()
        : this(new ProductRepository(), null)
    {
    }

    public ProductEditorWindow(ProductRepository repository, Product? product, string? initialBarcode = null)
    {
        _repository = repository;
        _productId = product?.Id;
        _initialBarcode = string.IsNullOrWhiteSpace(initialBarcode) ? null : initialBarcode.Trim();

        InitializeComponent();

        if (product is null)
        {
            SkuInput.Text = _repository.GenerateSku();
            BarcodeInput.Text = _initialBarcode;
            EditorTitle.Text = _initialBarcode is null ? "Nuovo prodotto" : "Nuovo prodotto da scansione";
        }
        else
        {
            EditorTitle.Text = "Modifica prodotto";
            SkuInput.Text = product.Sku;
            BarcodeInput.Text = product.Barcode;
            NameInput.Text = product.Name;
            BrandInput.Text = product.Brand;
            CategoryInput.Text = product.Category;
            VariantInput.Text = product.Variant;
            SizeInput.Text = product.Size;
            PurchasePriceInput.Text = FormatEditablePrice(product.PurchasePriceCents);
            SalePriceInput.Text = FormatEditablePrice(product.SalePriceCents);
            NotesInput.Text = product.Notes;
            IsActiveInput.IsChecked = product.IsActive;
        }

        Opened += (_, _) =>
        {
            if (product is null && _initialBarcode is not null)
            {
                NameInput.Focus();
                return;
            }

            SkuInput.Focus();
        };
    }

    private void GenerateSkuButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        SkuInput.Text = _repository.GenerateSku();
        SkuInput.Focus();
        SkuInput.CaretIndex = SkuInput.Text?.Length ?? 0;
    }

    private void BarcodeInput_OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
        {
            NameInput.Focus();
            e.Handled = true;
        }
    }

    private void SaveButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();

        var sku = SkuInput.Text?.Trim() ?? string.Empty;
        var name = NameInput.Text?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(sku))
        {
            ShowError("Il codice interno / SKU è obbligatorio.");
            SkuInput.Focus();
            return;
        }

        if (string.IsNullOrWhiteSpace(name))
        {
            ShowError("Il nome del prodotto è obbligatorio.");
            NameInput.Focus();
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

        var draft = new ProductDraft(
            _productId,
            sku,
            NormalizeOptional(BarcodeInput.Text),
            name,
            NormalizeOptional(CategoryInput.Text),
            NormalizeOptional(BrandInput.Text),
            NormalizeOptional(VariantInput.Text),
            NormalizeOptional(SizeInput.Text),
            purchasePriceCents,
            salePriceCents,
            NormalizeOptional(NotesInput.Text),
            IsActiveInput.IsChecked ?? false);

        try
        {
            _repository.Save(draft);
            Close(true);
        }
        catch (SqliteException ex) when (ex.SqliteErrorCode == 19)
        {
            ShowError("SKU o barcode già presente. Ogni prodotto deve avere codici univoci.");
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile salvare il prodotto: {ex.Message}");
        }
    }

    private void CancelButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        Close(false);
    }

    private static string? NormalizeOptional(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static bool TryParsePrice(string? text, out long? cents)
    {
        cents = null;
        if (string.IsNullOrWhiteSpace(text))
        {
            return true;
        }

        var value = text.Trim();
        if (!decimal.TryParse(value, NumberStyles.Number, CultureInfo.CurrentCulture, out var amount)
            && !decimal.TryParse(value.Replace(',', '.'), NumberStyles.Number, CultureInfo.InvariantCulture, out amount))
        {
            return false;
        }

        if (amount < 0)
        {
            return false;
        }

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
        ErrorPanel.IsVisible = false;
        ErrorText.Text = string.Empty;
    }
}
