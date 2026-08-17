namespace LocalStoreManagement.Desktop.Infrastructure;

public static class AppPaths
{
    private const string ApplicationFolderName = "LocalStoreManagementSystem";

    public static string DataDirectory { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        ApplicationFolderName);

    public static string DatabasePath { get; } = Path.Combine(DataDirectory, "store.db");
}
