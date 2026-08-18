using Avalonia.Controls;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private Button _cashNavButton = null!;
    private CashView? _cashView;

    private void EnsureCashNavigationButton()
    {
        if (_cashNavButton is not null) return;

        if (DashboardNavButton.Parent is not StackPanel navigationPanel)
        {
            throw new InvalidOperationException("Impossibile inizializzare la voce Cassa nel menu.");
        }

        _cashNavButton = new Button
        {
            Content = "Cassa"
        };
        _cashNavButton.Classes.Add("SidebarNav");
        _cashNavButton.Click += CashButton_OnClick;

        var dashboardIndex = navigationPanel.Children.IndexOf(DashboardNavButton);
        navigationPanel.Children.Insert(dashboardIndex >= 0 ? dashboardIndex + 1 : 0, _cashNavButton);
    }

    private void CashButton_OnClick(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
        => ShowCash();

    private void ShowCash()
    {
        HideEmbeddedViews();
        HideAllPanels();
        SetActiveNavigation(_cashNavButton);
        EnsureCashView();
        _cashView!.Reload();
        _cashView.IsVisible = true;
        PageTitle.Text = "Cassa";
        PageSubtitle.Text = "Scansione articoli, carrello e preparazione della vendita";
        _cashView.FocusPrimaryField();
    }

    private void EnsureCashView()
    {
        if (_cashView is not null) return;
        if (DashboardPanel.Parent is not Grid contentGrid)
        {
            throw new InvalidOperationException("Impossibile inizializzare il pannello Cassa.");
        }

        _cashView = new CashView(_productRepository) { IsVisible = false };
        contentGrid.Children.Add(_cashView);
    }

    private void HideCashView()
    {
        if (_cashView is not null) _cashView.IsVisible = false;
    }
}