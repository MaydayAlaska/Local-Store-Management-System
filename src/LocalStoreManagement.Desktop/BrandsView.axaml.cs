using Avalonia.Controls;
using LocalStoreManagement.Desktop.Data;
using LocalStoreManagement.Desktop.Models;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop;

public partial class BrandsView : UserControl
{
    private readonly BrandRepository _repository;

    public event EventHandler? BrandsChanged;

    public BrandsView()
        : this(new BrandRepository())
    {
    }

    public BrandsView(BrandRepository repository)
    {
        _repository = repository;
        InitializeComponent();
        Reload();
    }

    public void Reload(long? selectedId = null)
    {
        var brands = _repository.GetAll();
        BrandsList.ItemsSource = brands;
        EmptyBrandsText.IsVisible = brands.Count == 0;

        BrandsList.SelectedItem = selectedId.HasValue
            ? brands.FirstOrDefault(brand => brand.Id == selectedId.Value)
            : null;

        if (BrandsList.SelectedItem is null)
        {
            SelectedBrandNameInput.Clear();
            SelectedBrandNameInput.IsEnabled = false;
            RenameButton.IsEnabled = false;
            DeleteButton.IsEnabled = false;
        }
    }

    public void FocusPrimaryField() => NewBrandNameInput.Focus();

    private void CreateButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        try
        {
            var id = _repository.Create(NewBrandNameInput.Text ?? string.Empty);
            NewBrandNameInput.Clear();
            Reload(id);
            StatusText.Text = $"Marca creata con ID {id}.";
            BrandsChanged?.Invoke(this, EventArgs.Empty);
        }
        catch (SqliteException ex) when (ex.SqliteErrorCode == 19)
        {
            ShowError("Esiste già una marca con questo nome.");
        }
        catch (Exception ex)
        {
            ShowError(ex.Message);
        }
    }

    private void RenameButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        if (BrandsList.SelectedItem is not Brand brand)
        {
            return;
        }

        try
        {
            _repository.Rename(brand.Id, SelectedBrandNameInput.Text ?? string.Empty);
            Reload(brand.Id);
            StatusText.Text = $"Marca ID {brand.Id} rinominata.";
            BrandsChanged?.Invoke(this, EventArgs.Empty);
        }
        catch (SqliteException ex) when (ex.SqliteErrorCode == 19)
        {
            ShowError("Esiste già una marca con questo nome.");
        }
        catch (Exception ex)
        {
            ShowError(ex.Message);
        }
    }

    private async void DeleteButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        HideError();
        if (BrandsList.SelectedItem is not Brand selected)
        {
            return;
        }

        var latest = _repository.GetById(selected.Id);
        if (latest is null)
        {
            Reload();
            ShowError("La marca selezionata non esiste più.");
            return;
        }

        if (TopLevel.GetTopLevel(this) is not Window owner)
        {
            ShowError("Impossibile aprire la conferma di eliminazione.");
            return;
        }

        var possibleTargets = _repository.GetAll()
            .Where(brand => brand.Id != latest.Id)
            .ToList();

        var dialog = new BrandDeleteWindow(latest, possibleTargets);
        var confirmed = await dialog.ShowDialog<bool>(owner);
        if (!confirmed)
        {
            return;
        }

        try
        {
            _repository.DeleteAndReassign(latest.Id, dialog.TargetBrandId);
            Reload();
            StatusText.Text = latest.ProductCount == 0
                ? $"Marca “{latest.Name}” eliminata. L'ID {latest.Id} è ora disponibile."
                : $"Marca “{latest.Name}” eliminata e {latest.ProductCount} prodotti gestiti. L'ID {latest.Id} è ora disponibile.";
            BrandsChanged?.Invoke(this, EventArgs.Empty);
        }
        catch (Exception ex)
        {
            ShowError($"Impossibile eliminare la marca: {ex.Message}");
        }
    }

    private void BrandsList_OnSelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (BrandsList.SelectedItem is Brand brand)
        {
            SelectedBrandNameInput.Text = brand.Name;
            SelectedBrandNameInput.IsEnabled = true;
            RenameButton.IsEnabled = true;
            DeleteButton.IsEnabled = true;
            return;
        }

        SelectedBrandNameInput.Clear();
        SelectedBrandNameInput.IsEnabled = false;
        RenameButton.IsEnabled = false;
        DeleteButton.IsEnabled = false;
    }

    private void ShowError(string message)
    {
        ErrorText.Text = message;
        ErrorText.IsVisible = true;
    }

    private void HideError()
    {
        ErrorText.Text = string.Empty;
        ErrorText.IsVisible = false;
    }
}
