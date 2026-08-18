using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Avalonia.Threading;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Services;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop;

public partial class App : Application
{
    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        Dispatcher.UIThread.UnhandledException += OnUnhandledUiException;

        try
        {
            DatabaseInitializer.Initialize();
        }
        catch (Exception ex)
        {
            AppLog.Error("Database initialization at startup", ex);
            throw;
        }

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var mainWindow = new MainWindow();
            ApplyConfiguredWindowIcon(mainWindow);
            desktop.MainWindow = mainWindow;
        }

        base.OnFrameworkInitializationCompleted();
    }

    private static void OnUnhandledUiException(object? sender, DispatcherUnhandledExceptionEventArgs e)
    {
        AppLog.Error("Unhandled UI exception", e.Exception);

        // Gli errori di accesso a SQLite durante un'azione UI non devono chiudere l'intero
        // gestionale. L'azione corrente viene interrotta, l'errore resta nel log e l'utente
        // può continuare a usare l'applicazione o fornirci il file per la diagnosi.
        if (e.Exception is SqliteException or DatabaseAccessException)
        {
            e.Handled = true;
        }
    }

    private static void ApplyConfiguredWindowIcon(Window window)
    {
        try
        {
            var settingsService = new AppSettingsService();
            var customIconPath = settingsService.ResolveIconPath();
            if (customIconPath is not null)
            {
                ApplicationIconIntegrationService.Apply(window, customIconPath);
                return;
            }
        }
        catch
        {
            // In caso di impostazioni non leggibili si torna all'icona predefinita.
        }

        ApplyDefaultWindowIcon(window);
    }

    private static void ApplyDefaultWindowIcon(Window window)
    {
        if (window.Icon is not null)
        {
            return;
        }

        try
        {
            var sourcePath = Path.Combine(AppContext.BaseDirectory, "Assets", "app-icon.base64");
            if (!File.Exists(sourcePath))
            {
                return;
            }

            var iconBytes = Convert.FromBase64String(File.ReadAllText(sourcePath).Trim());
            var cacheDirectory = Path.Combine(Path.GetTempPath(), "LocalStoreManagementSystem");
            Directory.CreateDirectory(cacheDirectory);
            var iconPath = Path.Combine(cacheDirectory, "default-app-icon.png");
            File.WriteAllBytes(iconPath, iconBytes);
            window.Icon = new WindowIcon(iconPath);
        }
        catch
        {
            // L'icona predefinita non deve mai impedire l'avvio dell'applicazione.
        }
    }
}
