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

                CREATE TABLE IF NOT EXISTS categories (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL COLLATE NOCASE UNIQUE
                );

                CREATE TABLE IF NOT EXISTS products (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    sku TEXT NOT NULL UNIQUE,
                    barcode TEXT UNIQUE,
                    name TEXT NOT NULL,
                    category_id INTEGER,
                    brand TEXT,
                    variant TEXT,
                    size TEXT,
                    purchase_price_cents INTEGER,
                    sale_price_cents INTEGER,
                    notes TEXT,
                    is_active INTEGER NOT NULL DEFAULT 1,
                    created_at_utc TEXT NOT NULL,
                    updated_at_utc TEXT NOT NULL,
                    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
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

        // Migrazione non distruttiva per i database creati durante lo sviluppo.
        // Le vecchie colonne inutilizzate possono restare fisicamente presenti, ma
        // l'applicazione usa category_id e la tabella categories come fonte autorevole.
        EnsureColumn(connection, "products", "category_id", "INTEGER REFERENCES categories(id) ON DELETE SET NULL");
        EnsureColumn(connection, "products", "brand", "TEXT");
        EnsureColumn(connection, "products", "variant", "TEXT");
        EnsureColumn(connection, "products", "size", "TEXT");
        EnsureColumn(connection, "products", "notes", "TEXT");
        EnsureColumn(connection, "products", "is_active", "INTEGER NOT NULL DEFAULT 1");

        MigrateLegacyCategories(connection);

        using var indexCommand = connection.CreateCommand();
        indexCommand.CommandText = """
            CREATE INDEX IF NOT EXISTS ix_categories_name ON categories(name COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_products_barcode ON products(barcode);
            CREATE INDEX IF NOT EXISTS ix_products_brand ON products(brand COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_products_category_id ON products(category_id);
            CREATE INDEX IF NOT EXISTS ix_stock_movements_product_id ON stock_movements(product_id);
            CREATE INDEX IF NOT EXISTS ix_stock_movements_created_at ON stock_movements(created_at_utc DESC, id DESC);
            """;
        indexCommand.ExecuteNonQuery();
    }

    private static void MigrateLegacyCategories(SqliteConnection connection)
    {
        if (!HasColumn(connection, "products", "category"))
        {
            return;
        }

        using var transaction = connection.BeginTransaction();

        using (var insertCommand = connection.CreateCommand())
        {
            insertCommand.Transaction = transaction;
            insertCommand.CommandText = """
                INSERT OR IGNORE INTO categories (name)
                SELECT DISTINCT TRIM(category)
                FROM products
                WHERE category IS NOT NULL
                  AND TRIM(category) <> '';
                """;
            insertCommand.ExecuteNonQuery();
        }

        using (var updateCommand = connection.CreateCommand())
        {
            updateCommand.Transaction = transaction;
            updateCommand.CommandText = """
                UPDATE products
                SET category_id = (
                    SELECT c.id
                    FROM categories c
                    WHERE c.name = TRIM(products.category) COLLATE NOCASE
                    LIMIT 1
                )
                WHERE category_id IS NULL
                  AND category IS NOT NULL
                  AND TRIM(category) <> '';
                """;
            updateCommand.ExecuteNonQuery();
        }

        // Dopo la conversione il vecchio testo non deve più ricreare categorie
        // rinominate o eliminate ai successivi avvii.
        using (var clearLegacyCommand = connection.CreateCommand())
        {
            clearLegacyCommand.Transaction = transaction;
            clearLegacyCommand.CommandText = "UPDATE products SET category = NULL WHERE category IS NOT NULL;";
            clearLegacyCommand.ExecuteNonQuery();
        }

        transaction.Commit();
    }

    private static void EnsureColumn(SqliteConnection connection, string tableName, string columnName, string definition)
    {
        if (HasColumn(connection, tableName, columnName))
        {
            return;
        }

        using var alterCommand = connection.CreateCommand();
        alterCommand.CommandText = $"ALTER TABLE {tableName} ADD COLUMN {columnName} {definition};";
        alterCommand.ExecuteNonQuery();
    }

    private static bool HasColumn(SqliteConnection connection, string tableName, string columnName)
    {
        using var infoCommand = connection.CreateCommand();
        infoCommand.CommandText = $"PRAGMA table_info({tableName});";

        using var reader = infoCommand.ExecuteReader();
        while (reader.Read())
        {
            if (string.Equals(reader.GetString(1), columnName, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }
}
