using Avalonia.Controls;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public sealed record BrandDeleteTargetOption(long? Id, string DisplayName);

public partial class BrandDeleteWindow : Window
{
    private readonly Brand _brand;

    public BrandDeleteWindow()
        : this(new Brand(0, "Marca", 0), Array.Empty<Brand>())
    {
    }

    public BrandDeleteWindow(Brand brand, IReadOnlyList<Brand> possibleTargets)
    {
        _brand = brand;
        InitializeComponent();

        WarningText.Text = brand.ProductCount == 0
            ? $"Vuoi eliminare la marca “{brand.Name}” (ID {brand.Id})?"
            : $"La marca “{brand.Name}” (ID {brand.Id}) contiene {brand.ProductCount} prodotti. Prima dell'eliminazione scegli come gestirli.";

        ReassignPanel.IsVisible = brand.ProductCount > 0;

        var options = new List<BrandDeleteTargetOption>
        {
            new(null, "Lascia senza marca")
        };
        options.AddRange(possibleTargets.Select(target =>
            new BrandDeleteTargetOption(target.Id, $"{target.Name} (ID {target.Id})")));

        TargetBrandInput.ItemsSource = options;
        TargetBrandInput.SelectedIndex = 0;
    }

    public long? TargetBrandId => _brand.ProductCount > 0
        ? (TargetBrandInput.SelectedItem as BrandDeleteTargetOption)?.Id
        : null;

    private void ConfirmButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close(true);

    private void CancelButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => Close(false);
}
