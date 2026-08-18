using Avalonia.Controls;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop;

public partial class CategoriesWindow : Window
{
    private readonly CategoryRepository _repository;

    public CategoriesWindow()
        : this(new CategoryRepository())
    {
    }

    public CategoriesWindow(CategoryRepository repository)
    {
        _repository = repository;
        InitializeComponent();
        ReloadCategories();
    }

    private void CreateButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();

        try
        {
            var id = _repository.Create(NewCategoryNameInput.Text ?? string.Empty);
            NewCategoryNameInput.Clear();
            ReloadCategories(id);
            StatusText.Text = $"Categoria creata con ID {id}.";
        }
        catch (SqliteException ex) when (ex.SqliteErrorCode == 19)
        {
            ShowError("Esiste già una categoria con questo nome.");
        }
        catch (Exception ex)
        {
            ShowError(ex.Message);
        }
    }

    private void RenameButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();

        if (CategoriesList.SelectedItem is not Category category)
        {
            return;
        }

        try
        {
            _repository.Rename(category.Id, SelectedCategoryNameInput.Text ?? string.Empty);
            ReloadCategories(category.Id);
            StatusText.Text = $"Categoria ID {category.Id} rinominata.";
        }
        catch (SqliteException ex) when (ex.SqliteErrorCode == 19)
        {
            ShowError("Esiste già una categoria con questo nome.");
        }
        catch (Exception ex)
        {
            ShowError(ex.Message);
        }
    }

    private async void DeleteButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();

        if (CategoriesList.SelectedItem is not Category selected)
        {
            return;
        }

        var latest = _repository.GetById(selected.Id);
        if (latest is null)
        {
            ReloadCategories();
            ShowError("La categoria selezionata non esiste più.");
            return;
        }

        var possibleTargets = _repository.GetAll()
            .Where(category => category.Id != latest.Id)
            .ToList();

        var dialog = new CategoryDeleteWindow(latest, possibleTargets);
        var confirmed = await dialog.ShowDialog<bool>(this);
        if (!confirmed)
        {
            return;
        }

        try
        {
            _repository.DeleteAndReassign(latest.Id, dialog.TargetCategoryId);
            ReloadCategories();
            StatusText.Text = latest.ProductCount == 0
                ? $"Categoria “{latest.Name}” eliminata. L'ID {latest.Id} è ora disponibile."
                : $"Categoria “{latest.Name}” eliminata e {latest.ProductCount} prodotti gestiti. L'ID {latest.Id} è ora disponibile.";
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile eliminare la categoria: {ex.Message}");
        }
    }

    private void CategoriesList_OnSelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (CategoriesList.SelectedItem is Category category)
        {
            SelectedCategoryNameInput.Text = category.Name;
            SelectedCategoryNameInput.IsEnabled = true;
            RenameButton.IsEnabled = true;
            DeleteButton.IsEnabled = true;
            return;
        }

        SelectedCategoryNameInput.Clear();
        SelectedCategoryNameInput.IsEnabled = false;
        RenameButton.IsEnabled = false;
        DeleteButton.IsEnabled = false;
    }

    private void ReloadCategories(long? selectedId = null)
    {
        var categories = _repository.GetAll();
        CategoriesList.ItemsSource = categories;
        EmptyCategoriesText.IsVisible = categories.Count == 0;

        if (selectedId.HasValue)
        {
            CategoriesList.SelectedItem = categories.FirstOrDefault(category => category.Id == selectedId.Value);
        }
        else
        {
            CategoriesList.SelectedItem = null;
        }

        if (categories.Count == 0)
        {
            SelectedCategoryNameInput.Clear();
            SelectedCategoryNameInput.IsEnabled = false;
            RenameButton.IsEnabled = false;
            DeleteButton.IsEnabled = false;
        }
    }

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
