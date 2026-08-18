using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Layout;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private bool? _responsiveCompactMode;
    private bool _responsiveShopNameWasVisible;
    private bool _responsiveSubtitleWasVisible;
    private bool _responsiveLogoWasVisible;

    private void InitializeResponsiveLayout()
    {
        MinWidth = 720;
        MinHeight = 560;

        EnableHorizontalListScrolling(DashboardProductsList);
        EnableHorizontalListScrolling(ProductsList);
        EnableHorizontalListScrolling(WarehouseProductsList);
        EnableHorizontalListScrolling(MovementsList);

        DashboardSearchStatusText.TextWrapping = Avalonia.Media.TextWrapping.Wrap;
        DashboardProductCodeSummaryText.TextWrapping = Avalonia.Media.TextWrapping.Wrap;
        DashboardMovementStatusText.TextWrapping = Avalonia.Media.TextWrapping.Wrap;
        PageSubtitle.TextWrapping = Avalonia.Media.TextWrapping.Wrap;

        SizeChanged += (_, _) => ApplyResponsiveLayout(Bounds.Width);
        Opened += (_, _) => ApplyResponsiveLayout(Bounds.Width);
        ApplyResponsiveLayout(Width);
    }

    private static void EnableHorizontalListScrolling(Control control)
    {
        ScrollViewer.SetHorizontalScrollBarVisibility(control, ScrollBarVisibility.Auto);
    }

    private void ApplyResponsiveLayout(double width)
    {
        var compact = width > 0 && width < 980;
        var veryCompact = width > 0 && width < 820;
        var enteringCompact = compact && _responsiveCompactMode != true;
        var leavingCompact = !compact && _responsiveCompactMode == true;

        if (enteringCompact)
        {
            _responsiveShopNameWasVisible = ShopNameText.IsVisible;
            _responsiveSubtitleWasVisible = _sidebarSubtitleText?.IsVisible ?? false;
            _responsiveLogoWasVisible = _sidebarLogoImage?.IsVisible ?? false;
        }

        _responsiveCompactMode = compact;

        if (Content is Grid root && root.ColumnDefinitions.Count > 0)
        {
            root.ColumnDefinitions[0].Width = new GridLength(compact ? 84 : 248);

            var sidebar = root.Children.OfType<Border>().FirstOrDefault();
            if (sidebar is not null)
            {
                sidebar.Margin = compact ? new Thickness(8, 8, 0, 8) : new Thickness(12, 10, 0, 12);
                sidebar.Padding = compact ? new Thickness(8) : new Thickness(12);
            }

            var header = root.Children.OfType<Border>()
                .FirstOrDefault(border => Grid.GetColumn(border) == 1 && Grid.GetRow(border) == 0);
            if (header is not null)
            {
                header.Margin = compact ? new Thickness(12, 10, 12, 0) : new Thickness(24, 14, 24, 0);
                if (header.Child is Grid headerGrid)
                {
                    var statusPill = headerGrid.Children.OfType<Border>()
                        .FirstOrDefault(border => Grid.GetColumn(border) == 1);
                    if (statusPill is not null) statusPill.IsVisible = !veryCompact;
                }
            }
        }

        PageTitle.FontSize = compact ? 24 : 30;
        PageSubtitle.FontSize = compact ? 12 : 13;

        var contentMargin = compact ? new Thickness(12, 8, 12, 16) : new Thickness(24, 8, 24, 24);
        if (DashboardPanel.Content is StackPanel dashboardContent) dashboardContent.Margin = contentMargin;
        ProductsPanel.Margin = contentMargin;
        WarehousePanel.Margin = contentMargin;
        MovementsPanel.Margin = contentMargin;

        ApplyResponsiveSidebar(compact, leavingCompact);
    }

    private void ApplyResponsiveSidebar(bool compact, bool leavingCompact)
    {
        if (compact)
        {
            ShopNameText.IsVisible = false;
            if (_sidebarSubtitleText is not null) _sidebarSubtitleText.IsVisible = false;
            if (_sidebarLogoImage is not null)
            {
                _sidebarLogoImage.IsVisible = _responsiveLogoWasVisible;
                _sidebarLogoImage.MaxWidth = 52;
                _sidebarLogoImage.MaxHeight = 52;
                _sidebarLogoImage.HorizontalAlignment = HorizontalAlignment.Center;
                _sidebarLogoImage.Margin = new Thickness(0, 2, 0, 8);
            }
        }
        else
        {
            if (leavingCompact)
            {
                ShopNameText.IsVisible = _responsiveShopNameWasVisible;
                if (_sidebarSubtitleText is not null) _sidebarSubtitleText.IsVisible = _responsiveSubtitleWasVisible;
                if (_sidebarLogoImage is not null) _sidebarLogoImage.IsVisible = _responsiveLogoWasVisible;
            }

            if (_sidebarLogoImage is not null)
            {
                _sidebarLogoImage.MaxWidth = 170;
                _sidebarLogoImage.MaxHeight = 72;
                _sidebarLogoImage.HorizontalAlignment = HorizontalAlignment.Left;
                _sidebarLogoImage.Margin = new Thickness(0, 0, 0, 8);
            }
        }

        if (DashboardNavButton.Parent is StackPanel navigationPanel)
        {
            var sectionLabel = navigationPanel.Children.OfType<TextBlock>().FirstOrDefault();
            if (sectionLabel is not null) sectionLabel.IsVisible = !compact;
        }

        SetResponsiveNavigationButton(DashboardNavButton, "Dashboard", "⌂", compact);
        SetResponsiveNavigationButton(_cashNavButton, "Cassa", "€", compact);
        SetResponsiveNavigationButton(ProductsNavButton, "Prodotti", "▦", compact);
        SetResponsiveNavigationButton(WarehouseNavButton, "Magazzino", "⇅", compact);
        SetResponsiveNavigationButton(BrandsNavButton, "Marche", "◇", compact);
        SetResponsiveNavigationButton(CategoriesNavButton, "Categorie", "◌", compact);
        SetResponsiveNavigationButton(LabelsNavButton, "Etichette", "▤", compact);
        SetResponsiveNavigationButton(MovementsNavButton, "Movimenti", "↕", compact);
        SetResponsiveNavigationButton(ExportNavButton, "Esportazione", "⇩", compact);
        SettingsNavButton.HorizontalContentAlignment = HorizontalAlignment.Center;
    }

    private static void SetResponsiveNavigationButton(Button button, string fullText, string compactText, bool compact)
    {
        button.Content = compact ? compactText : fullText;
        button.HorizontalContentAlignment = compact ? HorizontalAlignment.Center : HorizontalAlignment.Left;
        button.FontSize = compact ? 18 : 13;
        ToolTip.SetTip(button, fullText);
    }
}
