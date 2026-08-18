using Avalonia.Controls;
using Avalonia.Input;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class CashView : UserControl
{
    private readonly ProductRepository _productRepository;
    private readonly List<CashCartLine> _cart = new();

    public CashView()
        : this(new ProductRepository())
    {
    }

    internal CashView(ProductRepository productRepository)
    {
        _productRepository = productRepository;
        InitializeComponent();
        ReloadProducts();
        UpdateCartView();
    }

    public void Reload()
    {
        RefreshCartFromDatabase();
        ReloadProducts();
        UpdateCartView();
    }

    public void FocusPrimaryField() => CashSearchInput.Focus();

    private void CashSearchInput_OnTextChanged(object? sender, TextChangedEventArgs e)
        => ReloadProducts();

    private void CashSearchInput_OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;

        e.Handled = true;
        var query = CashSearchInput.Text?.Trim();
        if (string.IsNullOrWhiteSpace(query))
        {
            CashSearchInput.Focus();
            return;
        }

        var exact = _productRepository.FindByBarcode(query);
        if (exact is not null)
        {
            var message = AddProductToCart(exact);
            PrepareForNextScan();
            CashSearchStatusText.Text = message;
            return;
        }

        if (CashProductsList.SelectedItem is Product selected)
        {
            var message = AddProductToCart(selected);
            PrepareForNextScan();
            CashSearchStatusText.Text = message;
            return;
        }

        PrepareForNextScan();
        CashSearchStatusText.Text = $"Nessun prodotto trovato per «{query}».";
    }

    private void CashProductsList_OnSelectionChanged(object? sender, SelectionChangedEventArgs e)
        => CashAddSelectedButton.IsEnabled = CashProductsList.SelectedItem is Product;

    private void CashProductsList_OnDoubleTapped(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => AddSelectedProduct();

    private void CashAddSelectedButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => AddSelectedProduct();

    private void CashCartList_OnSelectionChanged(object? sender, SelectionChangedEventArgs e)
        => UpdateSelectedLineButtons();

    private void CashDecreaseButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => ChangeSelectedQuantity(-1);

    private void CashIncreaseButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => ChangeSelectedQuantity(1);

    private void CashRemoveButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (CashCartList.SelectedItem is not CashCartLine line) return;

        _cart.RemoveAll(item => item.VariantId == line.VariantId);
        UpdateCartView();
        CashCartStatusText.Text = $"{line.Name} rimosso dal carrello.";
        CashSearchInput.Focus();
    }

    private void CashClearButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (_cart.Count == 0) return;

        _cart.Clear();
        UpdateCartView();
        CashCartStatusText.Text = "Carrello svuotato. Nessun movimento di magazzino è stato registrato.";
        CashSearchInput.Focus();
    }

    private void AddSelectedProduct()
    {
        if (CashProductsList.SelectedItem is not Product product) return;

        CashSearchStatusText.Text = AddProductToCart(product);
        CashSearchInput.SelectAll();
        CashSearchInput.Focus();
    }

    private string AddProductToCart(Product product)
    {
        var latest = _productRepository.GetById(product.Id);
        if (latest is null) return "Il prodotto selezionato non esiste più.";
        if (!latest.IsActive) return $"{latest.Name}: variante disattivata, non aggiunta.";
        if (!latest.SalePriceCents.HasValue) return $"{latest.Name}: prezzo di vendita non impostato.";
        if (latest.StockQuantity <= 0) return $"{latest.Name}: nessun pezzo disponibile in magazzino.";

        var index = _cart.FindIndex(line => line.VariantId == latest.Id);
        var currentQuantity = index >= 0 ? _cart[index].Quantity : 0;
        if (currentQuantity >= latest.StockQuantity)
        {
            return $"{latest.Name}: nel carrello ci sono già tutti i {latest.StockQuantity} pezzi disponibili.";
        }

        var updatedLine = new CashCartLine(latest, currentQuantity + 1);
        if (index >= 0)
        {
            _cart[index] = updatedLine;
        }
        else
        {
            _cart.Add(updatedLine);
        }

        UpdateCartView(latest.Id);
        CashCartStatusText.Text = "Vendita in preparazione: la giacenza verrà modificata solo quando sarà implementata la chiusura fiscale.";
        return $"Aggiunto: {latest.Name} · {latest.VariantDisplay}. Quantità nel carrello: {updatedLine.Quantity}.";
    }

    private void ChangeSelectedQuantity(int delta)
    {
        if (CashCartList.SelectedItem is not CashCartLine selected) return;

        var index = _cart.FindIndex(line => line.VariantId == selected.VariantId);
        if (index < 0) return;

        var latest = _productRepository.GetById(selected.VariantId);
        if (latest is null || !latest.IsActive || !latest.SalePriceCents.HasValue)
        {
            _cart.RemoveAt(index);
            UpdateCartView();
            CashCartStatusText.Text = "La variante non è più vendibile ed è stata rimossa dal carrello.";
            CashSearchInput.Focus();
            return;
        }

        var newQuantity = _cart[index].Quantity + delta;
        if (newQuantity < 1)
        {
            CashCartStatusText.Text = "Usa «Rimuovi» per eliminare completamente la riga.";
            UpdateSelectedLineButtons();
            CashSearchInput.Focus();
            return;
        }

        if (newQuantity > latest.StockQuantity)
        {
            CashCartStatusText.Text = $"Quantità massima raggiunta: {latest.StockQuantity} pezzi disponibili.";
            UpdateSelectedLineButtons();
            CashSearchInput.Focus();
            return;
        }

        _cart[index] = new CashCartLine(latest, newQuantity);
        UpdateCartView(latest.Id);
        CashCartStatusText.Text = $"{latest.Name}: quantità aggiornata a {newQuantity}.";
        CashSearchInput.Focus();
    }

    private void ReloadProducts()
    {
        var query = CashSearchInput.Text?.Trim();
        var selectedId = (CashProductsList.SelectedItem as Product)?.Id;
        var products = _productRepository.Search(query)
            .Take(50)
            .ToList();

        CashProductsList.ItemsSource = products;
        CashEmptyProductsText.IsVisible = products.Count == 0;

        Product? selected = null;
        if (selectedId.HasValue)
        {
            selected = products.FirstOrDefault(product => product.Id == selectedId.Value);
        }

        if (selected is null && !string.IsNullOrWhiteSpace(query) && products.Count == 1)
        {
            selected = products[0];
        }

        CashProductsList.SelectedItem = selected;
        CashAddSelectedButton.IsEnabled = selected is not null;

        if (string.IsNullOrWhiteSpace(query))
        {
            CashSearchStatusText.Text = products.Count == 0
                ? "Nessun prodotto disponibile. Crea prima l'anagrafica prodotti."
                : "Scanner HID pronto. Scansiona barcode/SKU oppure cerca un prodotto.";
        }
        else
        {
            CashSearchStatusText.Text = products.Count switch
            {
                0 => "Nessun prodotto trovato.",
                1 => "1 variante trovata. Premi Invio o aggiungila al carrello.",
                _ => $"{products.Count} varianti trovate. Seleziona quella da vendere."
            };
        }
    }

    private void RefreshCartFromDatabase()
    {
        if (_cart.Count == 0) return;

        var refreshed = new List<CashCartLine>(_cart.Count);
        var changed = false;

        foreach (var line in _cart)
        {
            var latest = _productRepository.GetById(line.VariantId);
            if (latest is null ||
                !latest.IsActive ||
                !latest.SalePriceCents.HasValue ||
                latest.StockQuantity <= 0)
            {
                changed = true;
                continue;
            }

            var maximumQuantity = Math.Min(latest.StockQuantity, int.MaxValue);
            var quantity = (int)Math.Min(line.Quantity, maximumQuantity);
            if (quantity != line.Quantity || latest != line.Product) changed = true;
            refreshed.Add(new CashCartLine(latest, quantity));
        }

        _cart.Clear();
        _cart.AddRange(refreshed);

        if (changed)
        {
            CashCartStatusText.Text = "Carrello aggiornato in base ai dati e alle giacenze correnti.";
        }
    }

    private void UpdateCartView(long? selectedVariantId = null)
    {
        selectedVariantId ??= (CashCartList.SelectedItem as CashCartLine)?.VariantId;

        var items = _cart.ToList();
        CashCartList.ItemsSource = items;
        CashEmptyCartText.IsVisible = items.Count == 0;
        CashClearButton.IsEnabled = items.Count > 0;

        var totalItems = items.Sum(line => line.Quantity);
        var totalCents = items.Sum(line => line.LineTotalCents);
        CashItemsCountText.Text = totalItems == 1 ? "1 articolo" : $"{totalItems} articoli";
        CashTotalText.Text = MoneyFormatter.Format(totalCents);

        CashCartList.SelectedItem = selectedVariantId.HasValue
            ? items.FirstOrDefault(line => line.VariantId == selectedVariantId.Value)
            : null;

        UpdateSelectedLineButtons();
    }

    private void UpdateSelectedLineButtons()
    {
        if (CashCartList.SelectedItem is not CashCartLine line)
        {
            CashDecreaseButton.IsEnabled = false;
            CashIncreaseButton.IsEnabled = false;
            CashRemoveButton.IsEnabled = false;
            return;
        }

        CashDecreaseButton.IsEnabled = line.Quantity > 1;
        CashIncreaseButton.IsEnabled = line.Quantity < line.Product.StockQuantity;
        CashRemoveButton.IsEnabled = true;
    }

    private void PrepareForNextScan()
    {
        CashSearchInput.Clear();
        CashSearchInput.Focus();
    }

    private sealed record CashCartLine(Product Product, int Quantity)
    {
        public long VariantId => Product.Id;
        public string Name => Product.Name;
        public string QuantityDisplay => Quantity.ToString();
        public long LineTotalCents => (Product.SalePriceCents ?? 0L) * Quantity;
        public string UnitPriceDisplay => MoneyFormatter.Format(Product.SalePriceCents);
        public string LineTotalDisplay => MoneyFormatter.Format(LineTotalCents);

        public string DetailsDisplay
        {
            get
            {
                var details = new List<string> { Product.Sku };
                if (!string.IsNullOrWhiteSpace(Product.Variant)) details.Add(Product.Variant.Trim());
                if (!string.IsNullOrWhiteSpace(Product.Size)) details.Add($"Taglia {Product.Size.Trim()}");
                return string.Join(" · ", details);
            }
        }
    }
}