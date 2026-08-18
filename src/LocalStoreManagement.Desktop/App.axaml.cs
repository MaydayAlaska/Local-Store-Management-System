using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using LocalStoreManagement.Desktop.Infrastructure;

namespace LocalStoreManagement.Desktop;

public partial class App : Application
{
    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        DatabaseInitializer.Initialize();

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var mainWindow = new MainWindow();
            if (mainWindow.Icon is null)
            {
                var defaultIconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "app-icon.png");
                if (File.Exists(defaultIconPath))
                {
                    try
                    {
                        mainWindow.Icon = new WindowIcon(defaultIconPath);
                    }
                    catch
                    {
                        // L'icona non deve impedire l'avvio dell'applicazione.
                    }
                }
            }

            desktop.MainWindow = mainWindow;
        }

        base.OnFrameworkInitializationCompleted();
    }
}
