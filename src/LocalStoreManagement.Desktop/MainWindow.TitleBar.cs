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
    private const double CustomTitleBarHeight = 36;

    private Image? _titleBarIconImage;
    private Bitmap? _titleBarIconBitmap;
    private Button? _maximizeRestoreButton;

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
            BorderThickness = new Thickness(0, 0, 0, 1),
            BorderBrush = new SolidColorBrush(Color.FromArgb(0x28, 0x7F, 0x7F, 0x7F))
        };
        titleBar.Bind(Border.BackgroundProperty, new Binding(nameof(Background)) { Source = this });
        WindowDecorationProperties.SetElementRole(titleBar, WindowDecorationsElementRole.TitleBar);

        var dock = new DockPanel
        {
            LastChildFill = true,
            Height = CustomTitleBarHeight
        };

        var captionButtons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Height = CustomTitleBarHeight
        };
        DockPanel.SetDock(captionButtons, Dock.Right);

        var minimizeButton = CreateCaptionButton("—", "Riduci a icona", WindowDecorationsElementRole.MinimizeButton);
        minimizeButton.Click += (_, _) => WindowState = Avalonia.Controls.WindowState.Minimized;

        _maximizeRestoreButton = CreateCaptionButton("□", "Massimizza", WindowDecorationsElementRole.MaximizeButton);
        _maximizeRestoreButton.Click += (_, _) =>
        {
            WindowState = WindowState == Avalonia.Controls.WindowState.Maximized
                ? Avalonia.Controls.WindowState.Normal
                : Avalonia.Controls.WindowState.Maximized;
        };

        var closeButton = CreateCaptionButton("×", "Chiudi", WindowDecorationsElementRole.CloseButton);
        closeButton.Classes.Add("TitleBarClose");
        closeButton.FontSize = 20;
        closeButton.Click += (_, _) => Close();

        captionButtons.Children.Add(minimizeButton);
        captionButtons.Children.Add(_maximizeRestoreButton);
        captionButtons.Children.Add(closeButton);
        dock.Children.Add(captionButtons);

        _titleBarIconImage = new Image
        {
            Width = 16,
            Height = 16,
            Stretch = Stretch.Uniform,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(10, 0, 8, 0)
        };
        DockPanel.SetDock(_titleBarIconImage, Dock.Left);
        dock.Children.Add(_titleBarIconImage);

        var titleText = new TextBlock
        {
            VerticalAlignment = VerticalAlignment.Center,
            FontSize = 12.5,
            FontWeight = FontWeight.SemiBold,
            Margin = new Thickness(0, 0, 12, 0)
        };
        titleText.Bind(TextBlock.TextProperty, new Binding(nameof(Title)) { Source = this });
        dock.Children.Add(titleText);

        titleBar.Child = dock;
        Grid.SetRow(titleBar, 0);
        Grid.SetColumnSpan(titleBar, Math.Max(1, rootGrid.ColumnDefinitions.Count));
        rootGrid.Children.Add(titleBar);

        RefreshTitleBarIcon();
        UpdateMaximizeRestoreButton();

        PropertyChanged += (_, change) =>
        {
            if (change.Property == WindowStateProperty)
            {
                UpdateMaximizeRestoreButton();
            }
            else if (change.Property == IconProperty)
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

    private static Button CreateCaptionButton(
        string content,
        string tooltip,
        WindowDecorationsElementRole role)
    {
        var button = new Button
        {
            Content = content,
            VerticalAlignment = VerticalAlignment.Stretch,
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        button.Classes.Add("TitleBarButton");
        ToolTip.SetTip(button, tooltip);
        WindowDecorationProperties.SetElementRole(button, role);
        return button;
    }

    private void UpdateMaximizeRestoreButton()
    {
        if (_maximizeRestoreButton is null)
        {
            return;
        }

        var maximized = WindowState == Avalonia.Controls.WindowState.Maximized;
        _maximizeRestoreButton.Content = maximized ? "❐" : "□";
        ToolTip.SetTip(_maximizeRestoreButton, maximized ? "Ripristina" : "Massimizza");
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
