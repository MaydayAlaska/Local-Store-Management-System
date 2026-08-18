using Avalonia.Controls;
using LocalStoreManagement.Desktop.Models;

namespace LocalStoreManagement.Desktop;

public sealed record CategoryDeleteTargetOption(long? Id, string DisplayName);

public partial class CategoryDeleteWindow : Window
{
    private readonly Category _category;

    public CategoryDeleteWindow()
        : this(new Category(0, "Categoria", 0), Array.Empty<Category>())
    {
    }

    public CategoryDeleteWindow(Category category, IReadOnlyList<Category> possibleTargets)
    {
        _category = category;
        InitializeComponent();

        WarningText.Text = category.ProductCount == 0
            ? $"Vuoi eliminare la categoria “{category.Name}” (ID {category.Id})?"
            : $"La categoria “{category.Name}” (ID {category.Id}) contiene {category.ProductCount} prodotti. Prima dell'eliminazione scegli come gestirli.";

        ReassignPanel.IsVisible = category.ProductCount > 0;

        var options = new List<CategoryDeleteTargetOption>
        {
            new(null, "Lascia senza categoria")
        };
        options.AddRange(possibleTargets.Select(target =>
            new CategoryDeleteTargetOption(target.Id, $"{target.Name} (ID {target.Id})")));

        TargetCategoryInput.ItemsSource = options;
        TargetCategoryInput.SelectedIndex = 0;
    }

    public long? TargetCategoryId => _category.ProductCount > 0
        ? (TargetCategoryInput.SelectedItem as CategoryDeleteTargetOption)?.Id
        : null;

    private void ConfirmButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        Close(true);
    }

    private void CancelButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        Close(false);
    }
}
