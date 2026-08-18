using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Infrastructure;

public sealed class DatabaseAccessException : Exception
{
    public DatabaseAccessException(string message, Exception innerException)
        : base(message, innerException)
    {
    }
}

public static class DatabaseConnectionFactory
{
    private const int ExpectedSchemaTableCount = 6;

    public static SqliteConnection Open()
    {
        SqliteConnection? connection = null;
        try
        {
            if (!File.Exists(AppPaths.DatabasePath))
            {
                AppLog.Info("DatabaseConnectionFactory", "store.db non esiste: inizializzazione automatica.");
                DatabaseInitializer.Initialize();
            }

            connection = OpenReadWriteConnection();
            if (!HasRequiredSchema(connection))
            {
                connection.Dispose();
                connection = null;

                AppLog.Info("DatabaseConnectionFactory", "Schema incompleto rilevato: avvio autoriparazione.");
                DatabaseInitializer.Initialize();

                connection = OpenReadWriteConnection();
                if (!HasRequiredSchema(connection))
                {
                    throw new InvalidOperationException(
                        "Il database esiste ma lo schema richiesto non è stato creato correttamente.");
                }
            }

            using var command = connection.CreateCommand();
            command.CommandText = "PRAGMA foreign_keys = ON;";
            command.ExecuteNonQuery();
            return connection;
        }
        catch (Exception ex)
        {
            connection?.Dispose();
            AppLog.Error("DatabaseConnectionFactory.Open", ex);
            throw new DatabaseAccessException(
                $"Impossibile aprire il database in «{AppPaths.DatabasePath}». Dettagli salvati in «{AppLog.LogPath}».",
                ex);
        }
    }

    private static SqliteConnection OpenReadWriteConnection()
    {
        var connection = new SqliteConnection(
            $"Data Source={AppPaths.DatabasePath};Mode=ReadWrite;Pooling=False;Default Timeout=5");
        connection.Open();
        return connection;
    }

    private static bool HasRequiredSchema(SqliteConnection connection)
    {
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT COUNT(*)
            FROM sqlite_master
            WHERE type = 'table'
              AND name IN (
                  'categories',
                  'brands',
                  'products',
                  'product_variants',
                  'product_barcodes',
                  'stock_movements');
            """;
        var count = Convert.ToInt32(command.ExecuteScalar() ?? 0);
        return count == ExpectedSchemaTableCount;
    }
}
