using Avalonia.Controls;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class StockMovementWindow : Window
{
    private readonly StockMovementRepository _repository;
    private readonly Product _product;
    private readonly StockMovementKind _kind;

    public StockMovementWindow()
        : this(new StockMovementRepository(), new Product(0, "", null, "", null, null, null, null, null, null, null, null, null, true, 0), StockMovementKind.Incoming)
    {
    }

    public StockMovementWindow(StockMovementRepository repository, Product product, StockMovementKind kind)
    {
        _repository = repository;
        _product = product;
        _kind = kind;

        InitializeComponent();

        ProductNameText.Text = product.Name;
        ProductCodeText.Text = string.IsNullOrWhiteSpace(product.Barcode)
            ? product.Sku
            : $"{product.Sku}  •  {product.Barcode}";
        CurrentStockText.Text = product.StockQuantity.ToString();

        switch (kind)
        {
            case StockMovementKind.Incoming:
                EditorTitle.Text = "Carico merce";
                EditorSubtitle.Text = "Aggiunge pezzi alla giacenza del prodotto.";
                QuantityLabel.Text = "Quantità da caricare";
                QuantityHelpText.Text = "Inserisci il numero di pezzi ricevuti.";
                QuantityInput.Minimum = 1;
                QuantityInput.Value = 1;
                break;

            case StockMovementKind.Outgoing:
                EditorTitle.Text = "Scarico merce";
                EditorSubtitle.Text = "Rimuove pezzi dalla giacenza del prodotto.";
                QuantityLabel.Text = "Quantità da scaricare";
                QuantityHelpText.Text = "Non è possibile portare la giacenza sotto zero.";
                QuantityInput.Minimum = 1;
                QuantityInput.Maximum = Math.Max(1, product.StockQuantity);
                QuantityInput.Value = product.StockQuantity > 0 ? 1 : 0;
                break;

            case StockMovementKind.Adjustment:
                EditorTitle.Text = "Rettifica giacenza";
                EditorSubtitle.Text = "Imposta la quantità reale registrando la differenza nello storico.";
                QuantityLabel.Text = "Nuova giacenza";
                QuantityHelpText.Text = "Indica quanti pezzi devono risultare dopo la rettifica.";
                QuantityInput.Minimum = 0;
                QuantityInput.Value = product.StockQuantity;
                break;
        }

        Opened += (_, _) => QuantityInput.Focus();
    }

    private void SaveButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();

        if (!QuantityInput.Value.HasValue)
        {
            ShowError("Inserisci una quantità valida.");
            return;
        }

        var decimalQuantity = QuantityInput.Value.Value;
        if (decimalQuantity != decimal.Truncate(decimalQuantity) || decimalQuantity > long.MaxValue)
        {
            ShowError("La quantità deve essere un numero intero.");
            return;
        }

        var quantity = (long)decimalQuantity;

        try
        {
            _repository.AddMovement(_product.Id, _kind, quantity, NoteInput.Text);
            Close(true);
        }
        catch (Exception ex)
        {
            ShowError(ex.Message);
        }
    }

    private void CancelButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        Close(false);
    }

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
