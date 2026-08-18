using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Chrome;
using Avalonia.Data;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using LocalStoreManagement.Desktop.Infrastructure;

namespace LocalStoreManagement.Desktop;

public partial class MainWindow
{
    private const double CustomTitleBarHeight = 46;

    private Image? _titleBarIconImage;
    private Bitmap? _titleBarIconBitmap;

    private void InitializeCustomTitleBar()
    {
        ExtendClientAreaToDecorationsHint = true;
        ExtendClientAreaTitleBarHeightHint = CustomTitleBarHeight;
        WindowDecorations = Avalonia.Controls.WindowDecorations.BorderOnly;

        if (Content is not Grid rootGrid)
        {
            return;
        }

        var existingChildren = rootGrid.Children.ToArray();
        foreach (var child in existingChildren)
        {
            Grid.SetRow(child, Grid.GetRow(child) + 1);
        }

        rootGrid.RowDefinitions.Insert(0, new RowDefinition
        {
            Height = new GridLength(CustomTitleBarHeight)
        });

        var titleBar = new Border
        {
            Height = CustomTitleBarHeight,
            Background = new SolidColorBrush(Color.FromRgb(0xF2, 0xF2, 0xF7)),
            BorderBrush = new SolidColorBrush(Color.FromRgb(0xE1, 0xE1, 0xE8)),
            BorderThickness = new Thickness(0, 0, 0, 1)
        };
        WindowDecorationProperties.SetElementRole(titleBar, WindowDecorationsElementRole.TitleBar);
        titleBar.DoubleTapped += (_, _) => ToggleMaximizeRestore();

        var titleGrid = new Grid
        {
            Height = CustomTitleBarHeight,
            ColumnDefinitions = new ColumnDefinitions("120,*,120")
        };

        var trafficLights = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 8,
            Margin = new Thickness(16, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Left
        };

        var closeButton = CreateTrafficButton(
            Color.FromRgb(0xFF, 0x5F, 0x57),
            "Chiudi",
            WindowDecorationsElementRole.CloseButton);
        closeButton.Click += (_, _) => Close();

        var minimizeButton = CreateTrafficButton(
            Color.FromRgb(0xFE, 0xBC, 0x2E),
            "Riduci a icona",
            WindowDecorationsElementRole.MinimizeButton);
        minimizeButton.Click += (_, _) => WindowState = Avalonia.Controls.WindowState.Minimized;

        var maximizeButton = CreateTrafficButton(
            Color.FromRgb(0x28, 0xC8, 0x40),
            "Massimizza / ripristina",
            WindowDecorationsElementRole.MaximizeButton);
        maximizeButton.Click += (_, _) => ToggleMaximizeRestore();

        trafficLights.Children.Add(closeButton);
        trafficLights.Children.Add(minimizeButton);
        trafficLights.Children.Add(maximizeButton);
        titleGrid.Children.Add(trafficLights);

        var centeredTitle = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Spacing = 7,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            IsHitTestVisible = false
        };
        Grid.SetColumn(centeredTitle, 1);

        _titleBarIconImage = new Image
        {
            Width = 18,
            Height = 18,
            Stretch = Stretch.Uniform,
            VerticalAlignment = VerticalAlignment.Center
        };
        centeredTitle.Children.Add(_titleBarIconImage);

        var titleText = new TextBlock
        {
            VerticalAlignment = VerticalAlignment.Center,
            FontSize = 12.5,
            FontWeight = FontWeight.SemiBold,
            Foreground = new SolidColorBrush(Color.FromRgb(0x1D, 0x1D, 0x1F)),
            MaxWidth = 560,
            TextTrimming = TextTrimming.CharacterEllipsis
        };
        titleText.Bind(TextBlock.TextProperty, new Binding(nameof(Title)) { Source = this });
        centeredTitle.Children.Add(titleText);
        titleGrid.Children.Add(centeredTitle);

        titleBar.Child = titleGrid;
        Grid.SetRow(titleBar, 0);
        Grid.SetColumnSpan(titleBar, Math.Max(1, rootGrid.ColumnDefinitions.Count));
        rootGrid.Children.Add(titleBar);

        RefreshTitleBarIcon();

        PropertyChanged += (_, change) =>
        {
            if (change.Property == IconProperty)
            {
                RefreshTitleBarIcon();
            }
        };

        Closed += (_, _) =>
        {
            _titleBarIconBitmap?.Dispose();
            _titleBarIconBitmap = null;
        };
    }

    private static Button CreateTrafficButton(
        Color color,
        string tooltip,
        WindowDecorationsElementRole role)
    {
        var button = new Button
        {
            Background = new SolidColorBrush(color),
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center
        };
        button.Classes.Add("TitleTraffic");
        ToolTip.SetTip(button, tooltip);
        WindowDecorationProperties.SetElementRole(button, role);
        return button;
    }

    private void ToggleMaximizeRestore()
    {
        WindowState = WindowState == Avalonia.Controls.WindowState.Maximized
            ? Avalonia.Controls.WindowState.Normal
            : Avalonia.Controls.WindowState.Maximized;
    }

    private void RefreshTitleBarIcon()
    {
        if (_titleBarIconImage is null)
        {
            return;
        }

        _titleBarIconBitmap?.Dispose();
        _titleBarIconBitmap = null;
        _titleBarIconImage.Source = null;

        try
        {
            var settingsService = new AppSettingsService();
            var customIconPath = settingsService.ResolveIconPath();
            if (customIconPath is not null)
            {
                try
                {
                    _titleBarIconBitmap = new Bitmap(customIconPath);
                    _titleBarIconImage.Source = _titleBarIconBitmap;
                    return;
                }
                catch
                {
                    // Se il formato non è renderizzabile come bitmap, usa l'icona predefinita.
                }
            }

            var sourcePath = Path.Combine(AppContext.BaseDirectory, "Assets", "app-icon.base64");
            if (!File.Exists(sourcePath))
            {
                return;
            }

            var iconBytes = Convert.FromBase64String(File.ReadAllText(sourcePath).Trim());
            using var stream = new MemoryStream(iconBytes, writable: false);
            _titleBarIconBitmap = new Bitmap(stream);
            _titleBarIconImage.Source = _titleBarIconBitmap;
        }
        catch
        {
            _titleBarIconImage.Source = null;
        }
    }
}
