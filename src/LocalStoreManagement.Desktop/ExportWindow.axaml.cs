using Avalonia.Controls;
using Avalonia.Platform.Storage;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;
using LocalStoreManagement.Desktop.Services;

namespace LocalStoreManagement.Desktop;

public sealed class ExportFilterOption
{
    public ExportFilterOption(string displayName, string? value)
    {
        DisplayName = displayName;
        Value = value;
    }

    public string DisplayName { get; }

    public string? Value { get; }

    public bool IsSelected { get; set; }
}

public partial class ExportWindow : Window
{
    private readonly ProductRepository _productRepository;
    private readonly AppSettingsService _settingsService;
    private readonly DatabaseBackupService _backupService = new();
    private readonly InventoryExcelExportService _excelExportService = new();
    private readonly List<ExportFilterOption> _brandOptions = new();
    private readonly List<ExportFilterOption> _categoryOptions = new();

    public ExportWindow()
        : this(new ProductRepository(), new AppSettingsService())
    {
    }

    public ExportWindow(ProductRepository productRepository, AppSettingsService settingsService)
    {
        _productRepository = productRepository;
        _settingsService = settingsService;

        InitializeComponent();
        DataDirectoryText.Text = $"Dati e backup: {AppPaths.DataDirectory}";
        LoadFilters();
    }

    private void LoadFilters()
    {
        var products = _productRepository.Search();

        _brandOptions.Clear();
        _brandOptions.AddRange(CreateFilterOptions(products.Select(product => product.Brand), "(Senza marca)"));
        BrandFilterList.ItemsSource = _brandOptions;

        _categoryOptions.Clear();
        _categoryOptions.AddRange(CreateFilterOptions(products.Select(product => product.Category), "(Senza categoria)"));
        CategoryFilterList.ItemsSource = _categoryOptions;

        FullExportSummaryText.Text = $"{products.Count} prodotti verranno esportati.";
    }

    private void BackupButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();

        try
        {
            var backupPath = _backupService.CreateBackup();
            BackupStatusText.Text = $"Backup creato: {backupPath}";
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile creare il backup: {ex.Message}");
        }
    }

    private async void FullExportButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        var products = _productRepository.Search();
        var options = BuildExportOptions(isPartial: false, "Tutte le marche e tutte le categorie.");
        await SaveExportAsync(products, options, "inventario-completo");
    }

    private async void PartialExportButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();

        var selectedBrands = _brandOptions.Where(option => option.IsSelected).ToList();
        var selectedCategories = _categoryOptions.Where(option => option.IsSelected).ToList();
        if (selectedBrands.Count == 0 && selectedCategories.Count == 0)
        {
            ShowError("Seleziona almeno una marca e/o una categoria per l'esportazione parziale.");
            return;
        }

        var products = _productRepository.Search()
            .Where(product => MatchesAny(product.Brand, selectedBrands))
            .Where(product => MatchesAny(product.Category, selectedCategories))
            .ToList();

        if (products.Count == 0)
        {
            ShowError("I filtri selezionati non corrispondono ad alcun prodotto.");
            return;
        }

        var summaryParts = new List<string>();
        if (selectedBrands.Count > 0)
        {
            summaryParts.Add("Marche: " + string.Join(", ", selectedBrands.Select(option => option.DisplayName)));
        }

        if (selectedCategories.Count > 0)
        {
            summaryParts.Add("Categorie: " + string.Join(", ", selectedCategories.Select(option => option.DisplayName)));
        }

        var filterSummary = string.Join(" · ", summaryParts);
        PartialExportSummaryText.Text = $"{products.Count} prodotti selezionati. {filterSummary}";

        var options = BuildExportOptions(isPartial: true, filterSummary);
        await SaveExportAsync(products, options, "inventario-parziale");
    }

    private async Task SaveExportAsync(
        IReadOnlyList<Product> products,
        InventoryExportOptions options,
        string fileNamePrefix)
    {
        if (!StorageProvider.CanSave)
        {
            ShowError("Il selettore per salvare file non è disponibile su questo sistema.");
            return;
        }

        var excelType = new FilePickerFileType("Cartella di lavoro Excel")
        {
            Patterns = new[] { "*.xlsx" },
            MimeTypes = new[] { "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
        };

        var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = options.IsPartial ? "Salva inventario parziale" : "Salva inventario completo",
            SuggestedFileName = $"{fileNamePrefix}-{DateTime.Now:yyyyMMdd}.xlsx",
            DefaultExtension = "xlsx",
            FileTypeChoices = new[] { excelType },
            SuggestedFileType = excelType,
            ShowOverwritePrompt = true
        });

        if (file is null)
        {
            return;
        }

        try
        {
            await using var stream = await file.OpenWriteAsync();
            if (stream.CanSeek)
            {
                stream.SetLength(0);
            }

            _excelExportService.Export(stream, products, options);
            await stream.FlushAsync();

            var exportLabel = options.IsPartial ? "Esportazione parziale completata" : "Esportazione completa completata";
            if (options.IsPartial)
            {
                PartialExportSummaryText.Text = $"{exportLabel}: {products.Count} prodotti · {file.Name}";
            }
            else
            {
                FullExportSummaryText.Text = $"{exportLabel}: {products.Count} prodotti · {file.Name}";
            }
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile creare il file Excel: {ex.Message}");
        }
    }

    private InventoryExportOptions BuildExportOptions(bool isPartial, string filterSummary)
    {
        var settings = _settingsService.Load();
        return new InventoryExportOptions(
            settings.ShopName,
            _settingsService.ResolveLogoPath(settings),
            isPartial,
            filterSummary);
    }

    private static bool MatchesAny(string? value, IReadOnlyList<ExportFilterOption> selectedOptions)
    {
        if (selectedOptions.Count == 0)
        {
            return true;
        }

        var normalizedValue = Normalize(value);
        return selectedOptions.Any(option =>
            string.Equals(Normalize(option.Value), normalizedValue, StringComparison.CurrentCultureIgnoreCase));
    }

    private static IEnumerable<ExportFilterOption> CreateFilterOptions(IEnumerable<string?> values, string emptyLabel)
    {
        var normalized = values
            .Select(Normalize)
            .Distinct(StringComparer.CurrentCultureIgnoreCase)
            .OrderBy(value => string.IsNullOrWhiteSpace(value) ? 1 : 0)
            .ThenBy(value => value, StringComparer.CurrentCultureIgnoreCase);

        foreach (var value in normalized)
        {
            yield return new ExportFilterOption(value ?? emptyLabel, value);
        }
    }

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private void CloseButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        Close();
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
