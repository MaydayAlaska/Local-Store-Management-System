using Avalonia.Controls;
using Avalonia.Input;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public partial class CashView : UserControl
{
    private readonly ProductRepository _productRepository;
    private readonly List<CashCartLine> _cart = new();
    private readonly List<CashFixedDiscountLine> _fixedDiscounts = new();
    private bool _resettingSaleDiscounts;
    private long _nextFixedDiscountId = 1;

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

    private void CashLineDiscountInput_OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;
        if (sender is not NumericUpDown input || input.DataContext is not CashCartLine line) return;

        e.Handled = true;
        var discountPercent = ClampPercent(input.Value ?? 0m);
        input.Value = discountPercent;

        if (line.DiscountPercent == discountPercent)
        {
            CashCartStatusText.Text = discountPercent == 0m
                ? $"Nessuno sconto applicato a {line.Name}."
                : $"Sconto del {discountPercent:0.##}% confermato su {line.Name}.";
            return;
        }

        line.DiscountPercent = discountPercent;
        UpdateCartView(line.VariantId);
        CashCartStatusText.Text = discountPercent == 0m
            ? $"Sconto rimosso da {line.Name}."
            : $"Sconto del {discountPercent:0.##}% applicato a {line.Name}.";
    }

    private void CashTotalDiscountPercentInput_OnValueChanged(object? sender, NumericUpDownValueChangedEventArgs e)
    {
        if (_resettingSaleDiscounts) return;

        var discountPercent = ClampPercent(CashTotalDiscountPercentInput.Value ?? 0m);
        if (CashTotalDiscountPercentInput.Value != discountPercent)
        {
            CashTotalDiscountPercentInput.Value = discountPercent;
            return;
        }

        UpdateCartTotals();
        CashCartStatusText.Text = discountPercent == 0m
            ? "Sconto percentuale sul totale rimosso."
            : $"Sconto del {discountPercent:0.##}% applicato al totale del carrello.";
    }

    private void CashFixedDiscountInput_OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter) return;

        e.Handled = true;
        AddFixedDiscountFromInput();
    }

    private void AddFixedDiscountFromInput()
    {
        if (_cart.Count == 0)
        {
            CashFixedDiscountInput.Value = 0m;
            CashCartStatusText.Text = "Aggiungi almeno un articolo prima di inserire uno sconto in euro.";
            CashSearchInput.Focus();
            return;
        }

        var amount = Math.Abs(CashFixedDiscountInput.Value ?? 0m);
        var amountCents = EuroAmountToCents(amount);
        if (amountCents <= 0)
        {
            CashCartStatusText.Text = "Inserisci uno sconto maggiore di 0 euro e premi Invio.";
            CashFixedDiscountInput.Focus();
            return;
        }

        var remainingBeforeFixedDiscount = Math.Max(
            0L,
            GetTotalBeforeFixedDiscountCents() - _fixedDiscounts.Sum(line => line.AmountCents));

        if (amountCents > remainingBeforeFixedDiscount)
        {
            CashCartStatusText.Text = $"Lo sconto supera il totale residuo di {MoneyFormatter.Format(remainingBeforeFixedDiscount)}.";
            CashFixedDiscountInput.Focus();
            return;
        }

        var discountLine = new CashFixedDiscountLine(_nextFixedDiscountId++, amountCents);
        _fixedDiscounts.Add(discountLine);
        CashFixedDiscountInput.Value = 0m;
        UpdateCartView(selectedFixedDiscountId: discountLine.Id);
        CashCartStatusText.Text = $"Sconto di {MoneyFormatter.Format(amountCents)} aggiunto al carrello come −{MoneyFormatter.Format(amountCents)}.";
        CashFixedDiscountInput.Focus();
    }

    private void CashRemoveButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        switch (CashCartList.SelectedItem)
        {
            case CashCartLine line:
                _cart.RemoveAll(item => item.VariantId == line.VariantId);
                UpdateCartView();
                CashCartStatusText.Text = $"{line.Name} rimosso dal carrello.";
                break;

            case CashFixedDiscountLine discountLine:
                _fixedDiscounts.RemoveAll(item => item.Id == discountLine.Id);
                UpdateCartView();
                CashCartStatusText.Text = $"Sconto di {MoneyFormatter.Format(discountLine.AmountCents)} rimosso dal carrello.";
                break;

            default:
                return;
        }

        CashSearchInput.Focus();
    }

    private void CashClearButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (_cart.Count == 0 && _fixedDiscounts.Count == 0) return;

        _cart.Clear();
        ResetSaleDiscounts();
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
        var currentLine = index >= 0 ? _cart[index] : null;
        var currentQuantity = currentLine?.Quantity ?? 0;
        if (currentQuantity >= latest.StockQuantity)
        {
            return $"{latest.Name}: nel carrello ci sono già tutti i {latest.StockQuantity} pezzi disponibili.";
        }

        var updatedLine = new CashCartLine(latest, currentQuantity + 1, currentLine?.DiscountPercent ?? 0m);
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

        _cart[index] = new CashCartLine(latest, newQuantity, _cart[index].DiscountPercent);
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
            refreshed.Add(new CashCartLine(latest, quantity, line.DiscountPercent));
        }

        _cart.Clear();
        _cart.AddRange(refreshed);

        if (_cart.Count == 0) ResetSaleDiscounts();

        if (changed)
        {
            CashCartStatusText.Text = "Carrello aggiornato in base ai dati e alle giacenze correnti.";
        }
    }

    private void UpdateCartView(long? selectedVariantId = null, long? selectedFixedDiscountId = null)
    {
        selectedVariantId ??= (CashCartList.SelectedItem as CashCartLine)?.VariantId;
        selectedFixedDiscountId ??= (CashCartList.SelectedItem as CashFixedDiscountLine)?.Id;

        if (_cart.Count == 0) ResetSaleDiscounts();

        var items = new List<object>(_cart.Count + _fixedDiscounts.Count);
        items.AddRange(_cart);
        items.AddRange(_fixedDiscounts);

        CashCartList.ItemsSource = items;
        CashEmptyCartText.IsVisible = items.Count == 0;
        CashClearButton.IsEnabled = items.Count > 0;
        CashTotalDiscountPercentInput.IsEnabled = _cart.Count > 0;
        CashFixedDiscountInput.IsEnabled = _cart.Count > 0;

        if (selectedVariantId.HasValue)
        {
            CashCartList.SelectedItem = items
                .OfType<CashCartLine>()
                .FirstOrDefault(line => line.VariantId == selectedVariantId.Value);
        }
        else if (selectedFixedDiscountId.HasValue)
        {
            CashCartList.SelectedItem = items
                .OfType<CashFixedDiscountLine>()
                .FirstOrDefault(line => line.Id == selectedFixedDiscountId.Value);
        }
        else
        {
            CashCartList.SelectedItem = null;
        }

        UpdateCartTotals();
        UpdateSelectedLineButtons();
    }

    private void UpdateCartTotals()
    {
        var totalItems = _cart.Sum(line => line.Quantity);
        var grossCents = _cart.Sum(line => line.GrossLineTotalCents);
        var subtotalCents = _cart.Sum(line => line.LineTotalCents);
        var itemDiscountCents = Math.Max(0L, grossCents - subtotalCents);

        var totalDiscountPercent = ClampPercent(CashTotalDiscountPercentInput.Value ?? 0m);
        var afterPercentCents = ApplyPercentDiscount(subtotalCents, totalDiscountPercent);
        var totalPercentDiscountCents = Math.Max(0L, subtotalCents - afterPercentCents);

        var requestedFixedDiscountCents = _fixedDiscounts.Sum(line => line.AmountCents);
        var fixedDiscountCents = Math.Min(requestedFixedDiscountCents, afterPercentCents);
        var finalTotalCents = Math.Max(0L, afterPercentCents - fixedDiscountCents);

        CashItemsCountText.Text = totalItems == 1 ? "1 articolo" : $"{totalItems} articoli";
        CashTotalText.Text = MoneyFormatter.Format(finalTotalCents);
        CashSubtotalText.Text = itemDiscountCents > 0
            ? $"Subtotale dopo sconti articolo: {MoneyFormatter.Format(subtotalCents)}"
            : $"Subtotale: {MoneyFormatter.Format(subtotalCents)}";

        var discounts = new List<string>();
        if (itemDiscountCents > 0)
        {
            discounts.Add($"articoli −{MoneyFormatter.Format(itemDiscountCents)}");
        }

        if (totalPercentDiscountCents > 0)
        {
            discounts.Add($"totale {totalDiscountPercent:0.##}% −{MoneyFormatter.Format(totalPercentDiscountCents)}");
        }

        if (fixedDiscountCents > 0)
        {
            discounts.Add($"fissi −{MoneyFormatter.Format(fixedDiscountCents)}");
        }

        CashDiscountSummaryText.Text = discounts.Count == 0
            ? "Nessuno sconto applicato"
            : $"Sconti: {string.Join(" · ", discounts)}";
    }

    private long GetTotalBeforeFixedDiscountCents()
    {
        var subtotalCents = _cart.Sum(line => line.LineTotalCents);
        var totalDiscountPercent = ClampPercent(CashTotalDiscountPercentInput.Value ?? 0m);
        return ApplyPercentDiscount(subtotalCents, totalDiscountPercent);
    }

    private void UpdateSelectedLineButtons()
    {
        switch (CashCartList.SelectedItem)
        {
            case CashCartLine line:
                CashDecreaseButton.IsEnabled = line.Quantity > 1;
                CashIncreaseButton.IsEnabled = line.Quantity < line.Product.StockQuantity;
                CashRemoveButton.IsEnabled = true;
                break;

            case CashFixedDiscountLine:
                CashDecreaseButton.IsEnabled = false;
                CashIncreaseButton.IsEnabled = false;
                CashRemoveButton.IsEnabled = true;
                break;

            default:
                CashDecreaseButton.IsEnabled = false;
                CashIncreaseButton.IsEnabled = false;
                CashRemoveButton.IsEnabled = false;
                break;
        }
    }

    private void ResetSaleDiscounts()
    {
        _resettingSaleDiscounts = true;
        try
        {
            CashTotalDiscountPercentInput.Value = 0m;
            CashFixedDiscountInput.Value = 0m;
            _fixedDiscounts.Clear();
        }
        finally
        {
            _resettingSaleDiscounts = false;
        }
    }

    private void PrepareForNextScan()
    {
        CashSearchInput.Clear();
        CashSearchInput.Focus();
    }

    private static decimal ClampPercent(decimal value)
        => Math.Clamp(value, 0m, 100m);

    private static long ApplyPercentDiscount(long cents, decimal discountPercent)
    {
        if (cents <= 0 || discountPercent <= 0m) return Math.Max(0L, cents);
        if (discountPercent >= 100m) return 0L;

        var discounted = cents * (100m - discountPercent) / 100m;
        return decimal.ToInt64(decimal.Round(discounted, 0, MidpointRounding.AwayFromZero));
    }

    private static long EuroAmountToCents(decimal amount)
        => decimal.ToInt64(decimal.Round(amount * 100m, 0, MidpointRounding.AwayFromZero));

    private sealed class CashCartLine
    {
        public CashCartLine(Product product, int quantity, decimal discountPercent = 0m)
        {
            Product = product;
            Quantity = quantity;
            DiscountPercent = ClampPercent(discountPercent);
        }

        public Product Product { get; }
        public int Quantity { get; }
        public decimal DiscountPercent { get; set; }
        public bool IsProductLine => true;
        public bool IsFixedDiscountLine => false;
        public long VariantId => Product.Id;
        public string Name => Product.Name;
        public string QuantityDisplay => Quantity.ToString();
        public long GrossLineTotalCents => (Product.SalePriceCents ?? 0L) * Quantity;
        public long LineTotalCents => ApplyPercentDiscount(GrossLineTotalCents, DiscountPercent);
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

    private sealed class CashFixedDiscountLine
    {
        public CashFixedDiscountLine(long id, long amountCents)
        {
            Id = id;
            AmountCents = Math.Max(0L, amountCents);
        }

        public long Id { get; }
        public long AmountCents { get; }
        public decimal DiscountPercent => 0m;
        public bool IsProductLine => false;
        public bool IsFixedDiscountLine => true;
        public string Name => "Sconto";
        public string DetailsDisplay => "Sconto fisso sul carrello";
        public string UnitPriceDisplay => MoneyFormatter.Format(-AmountCents);
        public string QuantityDisplay => "1";
        public string LineTotalDisplay => MoneyFormatter.Format(-AmountCents);
    }
}