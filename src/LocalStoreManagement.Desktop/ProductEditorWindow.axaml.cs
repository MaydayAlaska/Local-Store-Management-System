using Avalonia.Controls;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public sealed record CategorySelectionOption(long? Id, string DisplayName);
public sealed record BrandSelectionOption(long? Id, string DisplayName);

public partial class ProductEditorWindow : Window
{
    private readonly ProductRepository _repository;
    private readonly CategoryRepository _categoryRepository = new();
    private readonly BrandRepository _brandRepository = new();
    private readonly long? _productId;
    private readonly List<CategorySelectionOption> _categoryOptions = new();
    private readonly List<BrandSelectionOption> _brandOptions = new();
    private readonly List<ProductVariantDraft> _variants = new();

    public ProductEditorWindow() : this(new ProductRepository(), null) { }

    public ProductEditorWindow(ProductRepository repository, long? productId, string? initialBarcode = null)
    {
        _repository = repository;
        _productId = productId;

        InitializeComponent();

        ProductSummary? product = null;
        if (productId.HasValue)
        {
            product = _repository.GetProduct(productId.Value)
                ?? throw new InvalidOperationException("Il prodotto da modificare non esiste più.");
        }

        LoadBrands(product?.BrandId);
        LoadCategories(product?.CategoryId);

        if (product is null)
        {
            EditorTitle.Text = string.IsNullOrWhiteSpace(initialBarcode) ? "Nuovo prodotto" : "Nuovo prodotto da scansione";
            IsActiveInput.IsChecked = true;
            if (!string.IsNullOrWhiteSpace(initialBarcode))
            {
                _variants.Add(new ProductVariantDraft(
                    null,
                    _repository.GenerateSku(),
                    null,
                    null,
                    null,
                    null,
                    true,
                    new[] { initialBarcode.Trim() }));
            }
        }
        else
        {
            EditorTitle.Text = "Modifica prodotto";
            NameInput.Text = product.Name;
            NotesInput.Text = product.Notes;
            IsActiveInput.IsChecked = product.IsActive;
            _variants.AddRange(_repository.GetVariants(product.Id));
        }

        RefreshVariantList();
        Opened += (_, _) => NameInput.Focus();
    }

    private void LoadBrands(long? selectedBrandId)
    {
        _brandOptions.Clear();
        _brandOptions.Add(new BrandSelectionOption(null, "(Nessuna marca)"));
        _brandOptions.AddRange(_brandRepository.GetAll().Select(brand => new BrandSelectionOption(brand.Id, brand.Name)));
        BrandInput.ItemsSource = _brandOptions;
        BrandInput.SelectedItem = _brandOptions.FirstOrDefault(option => option.Id == selectedBrandId) ?? _brandOptions[0];
    }

    private void LoadCategories(long? selectedCategoryId)
    {
        _categoryOptions.Clear();
        _categoryOptions.Add(new CategorySelectionOption(null, "(Nessuna categoria)"));
        _categoryOptions.AddRange(_categoryRepository.GetAll().Select(category => new CategorySelectionOption(category.Id, category.Name)));
        CategoryInput.ItemsSource = _categoryOptions;
        CategoryInput.SelectedItem = _categoryOptions.FirstOrDefault(option => option.Id == selectedCategoryId) ?? _categoryOptions[0];
    }

    private async void AddVariantButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        var draft = new ProductVariantDraft(
            null,
            _repository.GenerateSku(),
            null,
            null,
            null,
            null,
            true,
            Array.Empty<string>());
        var editor = new ProductVariantEditorWindow(_repository, CurrentProductName(), draft, _variants.ToList());
        var result = await editor.ShowDialog<ProductVariantDraft?>(this);
        if (result is null) return;
        _variants.Add(result);
        RefreshVariantList(result);
    }

    private async void EditVariantButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await EditSelectedVariantAsync();

    private async void VariantsList_OnDoubleTapped(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => await EditSelectedVariantAsync();

    private async Task EditSelectedVariantAsync()
    {
        HideError();
        if (VariantsList.SelectedItem is not ProductVariantDraft selected)
        {
            ShowError("Seleziona la variante da modificare.");
            return;
        }

        var index = _variants.IndexOf(selected);
        if (index < 0) return;
        var others = _variants.Where((_, itemIndex) => itemIndex != index).ToList();
        var editor = new ProductVariantEditorWindow(_repository, CurrentProductName(), selected, others);
        var result = await editor.ShowDialog<ProductVariantDraft?>(this);
        if (result is null) return;
        _variants[index] = result;
        RefreshVariantList(result);
    }

    private void RemoveVariantButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        if (VariantsList.SelectedItem is not ProductVariantDraft selected)
        {
            ShowError("Seleziona la variante da rimuovere.");
            return;
        }

        if (selected.Id.HasValue)
        {
            ShowError("Una variante già salvata non viene eliminata per preservare lo storico dei movimenti. Aprila con «Modifica» e disattivala.");
            return;
        }

        _variants.Remove(selected);
        RefreshVariantList();
    }

    private void SaveButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        var name = NameInput.Text?.Trim() ?? string.Empty;
        if (name.Length == 0)
        {
            ShowError("Il nome del prodotto / modello è obbligatorio.");
            NameInput.Focus();
            return;
        }
        if (_variants.Count == 0)
        {
            ShowError("Aggiungi almeno una variante con SKU e, se disponibile, barcode.");
            return;
        }

        var selectedCategoryId = (CategoryInput.SelectedItem as CategorySelectionOption)?.Id;
        var selectedBrandId = (BrandInput.SelectedItem as BrandSelectionOption)?.Id;
        var draft = new ProductDraft(
            _productId,
            name,
            selectedCategoryId,
            selectedBrandId,
            NormalizeOptional(NotesInput.Text),
            IsActiveInput.IsChecked ?? false,
            _variants.ToList());

        try
        {
            _repository.Save(draft);
            Close(true);
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile salvare il prodotto: {ex.Message}");
        }
    }

    private void CancelButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close(false);

    private void RefreshVariantList(ProductVariantDraft? selected = null)
    {
        VariantsList.ItemsSource = null;
        VariantsList.ItemsSource = _variants.ToList();
        VariantsList.SelectedItem = selected;
        VariantsHintText.Text = _variants.Count switch
        {
            0 => "Nessuna variante: aggiungine almeno una prima di salvare il prodotto.",
            1 => "1 variante configurata. SKU e barcode identificano questa specifica combinazione.",
            _ => $"{_variants.Count} varianti configurate. Ogni barcode identifica direttamente colore/taglia e relativa giacenza."
        };
    }

    private string CurrentProductName()
        => string.IsNullOrWhiteSpace(NameInput.Text) ? "Nuovo prodotto" : NameInput.Text.Trim();

    private static string? NormalizeOptional(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

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
