using LocalStoreManagement.Desktop.Data;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Infrastructure;

public static class DatabaseSmokeTest
{
    public static void Run()
    {
        var testDirectory = Path.Combine(
            Path.GetTempPath(),
            $"LocalStoreManagement-db-smoke-{Guid.NewGuid():N}");
        Environment.SetEnvironmentVariable("LSMS_DATA_DIRECTORY_OVERRIDE", testDirectory);

        try
        {
            DatabaseInitializer.Initialize();
            VerifyRepositoryReads("prima creazione");

            SqliteConnection.ClearAllPools();
            File.Delete(AppPaths.DatabasePath);
            TryDelete(AppPaths.DatabasePath + "-wal");
            TryDelete(AppPaths.DatabasePath + "-shm");

            DatabaseInitializer.Initialize();
            VerifyRepositoryReads("dopo eliminazione e ricreazione");
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            try
            {
                if (Directory.Exists(testDirectory)) Directory.Delete(testDirectory, recursive: true);
            }
            catch
            {
                // Il runner CI è effimero: la pulizia del test è best effort.
            }
        }
    }

    private static void VerifyRepositoryReads(string phase)
    {
        var products = new ProductRepository();
        var brands = new BrandRepository();
        var categories = new CategoryRepository();
        var movements = new StockMovementRepository();

        _ = brands.GetAll();
        _ = categories.GetAll();
        _ = products.Count();
        _ = products.Search();
        _ = products.SearchProducts();
        _ = movements.GetTotalStock();
        _ = movements.Search(limit: 10);

        using var connection = DatabaseConnectionFactory.Open();
        using var command = connection.CreateCommand();
        command.CommandText = "PRAGMA quick_check;";
        var result = Convert.ToString(command.ExecuteScalar());
        if (!string.Equals(result, "ok", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"SQLite quick_check non riuscito ({phase}): {result}");
        }
    }

    private static void TryDelete(string path)
    {
        try
        {
            if (File.Exists(path)) File.Delete(path);
        }
        catch
        {
            // Il test principale deve riportare l'errore reale di inizializzazione/query.
        }
    }
}
