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

                CREATE TABLE IF NOT EXISTS brands (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL COLLATE NOCASE UNIQUE
                );

                CREATE TABLE IF NOT EXISTS products (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    sku TEXT NOT NULL UNIQUE,
                    barcode TEXT UNIQUE,
                    name TEXT NOT NULL,
                    category_id INTEGER,
                    brand_id INTEGER,
                    variant TEXT,
                    size TEXT,
                    purchase_price_cents INTEGER,
                    sale_price_cents INTEGER,
                    notes TEXT,
                    is_active INTEGER NOT NULL DEFAULT 1,
                    created_at_utc TEXT NOT NULL,
                    updated_at_utc TEXT NOT NULL,
                    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
                    FOREIGN KEY (brand_id) REFERENCES brands(id) ON DELETE SET NULL
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

        EnsureColumn(connection, "products", "category_id", "INTEGER REFERENCES categories(id) ON DELETE SET NULL");
        EnsureColumn(connection, "products", "brand_id", "INTEGER REFERENCES brands(id) ON DELETE SET NULL");
        EnsureColumn(connection, "products", "variant", "TEXT");
        EnsureColumn(connection, "products", "size", "TEXT");
        EnsureColumn(connection, "products", "notes", "TEXT");
        EnsureColumn(connection, "products", "is_active", "INTEGER NOT NULL DEFAULT 1");

        MigrateLegacyCategories(connection);
        MigrateLegacyBrands(connection);

        using var indexCommand = connection.CreateCommand();
        indexCommand.CommandText = """
            CREATE INDEX IF NOT EXISTS ix_categories_name ON categories(name COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_brands_name ON brands(name COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_products_barcode ON products(barcode);
            CREATE INDEX IF NOT EXISTS ix_products_brand_id ON products(brand_id);
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
                WHERE category IS NOT NULL AND TRIM(category) <> '';
                """;
            insertCommand.ExecuteNonQuery();
        }

        using (var updateCommand = connection.CreateCommand())
        {
            updateCommand.Transaction = transaction;
            updateCommand.CommandText = """
                UPDATE products
                SET category_id = (
                    SELECT c.id FROM categories c
                    WHERE c.name = TRIM(products.category) COLLATE NOCASE LIMIT 1
                )
                WHERE category_id IS NULL AND category IS NOT NULL AND TRIM(category) <> '';
                """;
            updateCommand.ExecuteNonQuery();
        }

        using (var clearCommand = connection.CreateCommand())
        {
            clearCommand.Transaction = transaction;
            clearCommand.CommandText = "UPDATE products SET category = NULL WHERE category IS NOT NULL;";
            clearCommand.ExecuteNonQuery();
        }

        transaction.Commit();
    }

    private static void MigrateLegacyBrands(SqliteConnection connection)
    {
        if (!HasColumn(connection, "products", "brand"))
        {
            return;
        }

        using var transaction = connection.BeginTransaction();
        using (var insertCommand = connection.CreateCommand())
        {
            insertCommand.Transaction = transaction;
            insertCommand.CommandText = """
                INSERT OR IGNORE INTO brands (name)
                SELECT DISTINCT TRIM(brand)
                FROM products
                WHERE brand IS NOT NULL AND TRIM(brand) <> '';
                """;
            insertCommand.ExecuteNonQuery();
        }

        using (var updateCommand = connection.CreateCommand())
        {
            updateCommand.Transaction = transaction;
            updateCommand.CommandText = """
                UPDATE products
                SET brand_id = (
                    SELECT b.id FROM brands b
                    WHERE b.name = TRIM(products.brand) COLLATE NOCASE LIMIT 1
                )
                WHERE brand_id IS NULL AND brand IS NOT NULL AND TRIM(brand) <> '';
                """;
            updateCommand.ExecuteNonQuery();
        }

        using (var clearCommand = connection.CreateCommand())
        {
            clearCommand.Transaction = transaction;
            clearCommand.CommandText = "UPDATE products SET brand = NULL WHERE brand IS NOT NULL;";
            clearCommand.ExecuteNonQuery();
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
