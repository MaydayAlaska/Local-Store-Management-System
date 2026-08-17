using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Infrastructure;

public static class DatabaseInitializer
{
    public static void Initialize()
    {
        Directory.CreateDirectory(AppPaths.DataDirectory);

        using var connection = new SqliteConnection($"Data Source={AppPaths.DatabasePath}");
        connection.Open();

        using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                PRAGMA foreign_keys = ON;
                PRAGMA journal_mode = WAL;

                CREATE TABLE IF NOT EXISTS products (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    sku TEXT NOT NULL UNIQUE,
                    barcode TEXT UNIQUE,
                    name TEXT NOT NULL,
                    category TEXT,
                    brand TEXT,
                    variant TEXT,
                    size TEXT,
                    purchase_price_cents INTEGER,
                    sale_price_cents INTEGER,
                    notes TEXT,
                    is_active INTEGER NOT NULL DEFAULT 1,
                    created_at_utc TEXT NOT NULL,
                    updated_at_utc TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS stock_movements (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    product_id INTEGER NOT NULL,
                    movement_type TEXT NOT NULL,
                    quantity_delta INTEGER NOT NULL,
                    note TEXT,
                    created_at_utc TEXT NOT NULL,
                    FOREIGN KEY (product_id) REFERENCES products(id)
                );
                """;

            command.ExecuteNonQuery();
        }

        // Migrazione non distruttiva per i database creati dalla foundation iniziale.
        // Le vecchie colonne stock_quantity/minimum_stock possono restare fisicamente
        // presenti in un database di sviluppo, ma non sono piu usate dall'applicazione.
        EnsureColumn(connection, "products", "brand", "TEXT");
        EnsureColumn(connection, "products", "variant", "TEXT");
        EnsureColumn(connection, "products", "size", "TEXT");
        EnsureColumn(connection, "products", "notes", "TEXT");
        EnsureColumn(connection, "products", "is_active", "INTEGER NOT NULL DEFAULT 1");

        using var indexCommand = connection.CreateCommand();
        indexCommand.CommandText = """
            CREATE INDEX IF NOT EXISTS ix_products_barcode ON products(barcode);
            CREATE INDEX IF NOT EXISTS ix_products_brand ON products(brand COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_products_category ON products(category COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_stock_movements_product_id ON stock_movements(product_id);
            CREATE INDEX IF NOT EXISTS ix_stock_movements_created_at ON stock_movements(created_at_utc DESC, id DESC);
            """;
        indexCommand.ExecuteNonQuery();
    }

    private static void EnsureColumn(SqliteConnection connection, string tableName, string columnName, string definition)
    {
        using var infoCommand = connection.CreateCommand();
        infoCommand.CommandText = $"PRAGMA table_info({tableName});";

        using var reader = infoCommand.ExecuteReader();
        while (reader.Read())
        {
            if (string.Equals(reader.GetString(1), columnName, StringComparison.OrdinalIgnoreCase))
            {
                return;
            }
        }

        reader.Close();

        using var alterCommand = connection.CreateCommand();
        alterCommand.CommandText = $"ALTER TABLE {tableName} ADD COLUMN {columnName} {definition};";
        alterCommand.ExecuteNonQuery();
    }
}
