using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Infrastructure;

public static class DatabaseInitializer
{
    public static void Initialize()
    {
        Directory.CreateDirectory(AppPaths.DataDirectory);

        using var connection = new SqliteConnection($"Data Source={AppPaths.DatabasePath}");
        connection.Open();

        Execute(connection, "PRAGMA journal_mode = WAL;");
        Execute(connection, "PRAGMA foreign_keys = ON;");
        CreateLookupTables(connection);

        if (!TableExists(connection, "products"))
        {
            CreateCatalogSchema(connection);
        }
        else if (HasColumn(connection, "products", "sku"))
        {
            // Schema storico: ogni riga prodotto rappresentava in realtà una singola variante.
            EnsureLegacyColumns(connection);
            MigrateLegacyCategories(connection);
            MigrateLegacyBrands(connection);
            CreatePreMigrationBackup(connection);
            MigrateToProductVariantSchema(connection);
        }
        else
        {
            CreateCatalogSchema(connection);
        }

        CreateIndexes(connection);
        Execute(connection, "PRAGMA user_version = 2;");
    }

    private static void CreateLookupTables(SqliteConnection connection)
    {
        Execute(connection, """
            CREATE TABLE IF NOT EXISTS categories (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL COLLATE NOCASE UNIQUE
            );

            CREATE TABLE IF NOT EXISTS brands (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL COLLATE NOCASE UNIQUE
            );
            """);
    }

    private static void CreateCatalogSchema(SqliteConnection connection, SqliteTransaction? transaction = null)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                category_id INTEGER,
                brand_id INTEGER,
                notes TEXT,
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at_utc TEXT NOT NULL,
                updated_at_utc TEXT NOT NULL,
                FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
                FOREIGN KEY (brand_id) REFERENCES brands(id) ON DELETE SET NULL
            );

            CREATE TABLE IF NOT EXISTS product_variants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER NOT NULL,
                sku TEXT NOT NULL COLLATE NOCASE UNIQUE,
                variant TEXT,
                size TEXT,
                purchase_price_cents INTEGER,
                sale_price_cents INTEGER,
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at_utc TEXT NOT NULL,
                updated_at_utc TEXT NOT NULL,
                FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
            );

            CREATE TABLE IF NOT EXISTS product_barcodes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                variant_id INTEGER NOT NULL,
                barcode TEXT NOT NULL UNIQUE,
                is_primary INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS stock_movements (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                variant_id INTEGER NOT NULL,
                movement_type TEXT NOT NULL,
                quantity_delta INTEGER NOT NULL,
                note TEXT,
                created_at_utc TEXT NOT NULL,
                FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE RESTRICT
            );
            """;
        command.ExecuteNonQuery();
    }

    private static void EnsureLegacyColumns(SqliteConnection connection)
    {
        EnsureColumn(connection, "products", "category_id", "INTEGER REFERENCES categories(id) ON DELETE SET NULL");
        EnsureColumn(connection, "products", "brand_id", "INTEGER REFERENCES brands(id) ON DELETE SET NULL");
        EnsureColumn(connection, "products", "variant", "TEXT");
        EnsureColumn(connection, "products", "size", "TEXT");
        EnsureColumn(connection, "products", "notes", "TEXT");
        EnsureColumn(connection, "products", "is_active", "INTEGER NOT NULL DEFAULT 1");
    }

    private static void MigrateToProductVariantSchema(SqliteConnection connection)
    {
        var hasLegacyMovements = TableExists(connection, "stock_movements");

        Execute(connection, "PRAGMA foreign_keys = OFF;");
        using var transaction = connection.BeginTransaction();
        try
        {
            Execute(connection, "ALTER TABLE products RENAME TO legacy_products;", transaction);
            if (hasLegacyMovements)
            {
                Execute(connection, "ALTER TABLE stock_movements RENAME TO legacy_stock_movements;", transaction);
            }

            CreateCatalogSchema(connection, transaction);

            Execute(connection, """
                INSERT INTO products (
                    id, name, category_id, brand_id, notes, is_active,
                    created_at_utc, updated_at_utc)
                SELECT
                    id, name, category_id, brand_id, notes, COALESCE(is_active, 1),
                    created_at_utc, updated_at_utc
                FROM legacy_products;
                """, transaction);

            Execute(connection, """
                INSERT INTO product_variants (
                    id, product_id, sku, variant, size,
                    purchase_price_cents, sale_price_cents, is_active,
                    created_at_utc, updated_at_utc)
                SELECT
                    id, id, sku, variant, size,
                    purchase_price_cents, sale_price_cents, COALESCE(is_active, 1),
                    created_at_utc, updated_at_utc
                FROM legacy_products;
                """, transaction);

            Execute(connection, """
                INSERT INTO product_barcodes (variant_id, barcode, is_primary)
                SELECT id, TRIM(barcode), 1
                FROM legacy_products
                WHERE barcode IS NOT NULL AND TRIM(barcode) <> '';
                """, transaction);

            if (hasLegacyMovements)
            {
                Execute(connection, """
                    INSERT INTO stock_movements (
                        id, variant_id, movement_type, quantity_delta, note, created_at_utc)
                    SELECT
                        id, product_id, movement_type, quantity_delta, note, created_at_utc
                    FROM legacy_stock_movements;
                    """, transaction);
            }

            Execute(connection, "DROP TABLE legacy_products;", transaction);
            if (hasLegacyMovements)
            {
                Execute(connection, "DROP TABLE legacy_stock_movements;", transaction);
            }

            transaction.Commit();
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
        finally
        {
            Execute(connection, "PRAGMA foreign_keys = ON;");
        }
    }

    private static void CreatePreMigrationBackup(SqliteConnection connection)
    {
        var backupDirectory = Path.Combine(AppPaths.DataDirectory, "Backups");
        Directory.CreateDirectory(backupDirectory);
        var backupPath = Path.Combine(
            backupDirectory,
            $"store-pre-variants-{DateTime.Now:yyyyMMdd-HHmmss}.db");

        using var destination = new SqliteConnection($"Data Source={backupPath}");
        destination.Open();
        connection.BackupDatabase(destination);
    }

    private static void CreateIndexes(SqliteConnection connection)
    {
        Execute(connection, """
            CREATE INDEX IF NOT EXISTS ix_categories_name ON categories(name COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_brands_name ON brands(name COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_products_brand_id ON products(brand_id);
            CREATE INDEX IF NOT EXISTS ix_products_category_id ON products(category_id);
            CREATE INDEX IF NOT EXISTS ix_product_variants_product_id ON product_variants(product_id);
            CREATE INDEX IF NOT EXISTS ix_product_variants_sku ON product_variants(sku COLLATE NOCASE);
            CREATE INDEX IF NOT EXISTS ix_product_barcodes_variant_id ON product_barcodes(variant_id);
            CREATE INDEX IF NOT EXISTS ix_product_barcodes_barcode ON product_barcodes(barcode);
            CREATE INDEX IF NOT EXISTS ix_stock_movements_variant_id ON stock_movements(variant_id);
            CREATE INDEX IF NOT EXISTS ix_stock_movements_created_at ON stock_movements(created_at_utc DESC, id DESC);
            """);
    }

    private static void MigrateLegacyCategories(SqliteConnection connection)
    {
        if (!HasColumn(connection, "products", "category")) return;

        using var transaction = connection.BeginTransaction();
        Execute(connection, """
            INSERT OR IGNORE INTO categories (name)
            SELECT DISTINCT TRIM(category)
            FROM products
            WHERE category IS NOT NULL AND TRIM(category) <> '';
            """, transaction);
        Execute(connection, """
            UPDATE products
            SET category_id = (
                SELECT c.id FROM categories c
                WHERE c.name = TRIM(products.category) COLLATE NOCASE LIMIT 1
            )
            WHERE category_id IS NULL AND category IS NOT NULL AND TRIM(category) <> '';
            """, transaction);
        transaction.Commit();
    }

    private static void MigrateLegacyBrands(SqliteConnection connection)
    {
        if (!HasColumn(connection, "products", "brand")) return;

        using var transaction = connection.BeginTransaction();
        Execute(connection, """
            INSERT OR IGNORE INTO brands (name)
            SELECT DISTINCT TRIM(brand)
            FROM products
            WHERE brand IS NOT NULL AND TRIM(brand) <> '';
            """, transaction);
        Execute(connection, """
            UPDATE products
            SET brand_id = (
                SELECT b.id FROM brands b
                WHERE b.name = TRIM(products.brand) COLLATE NOCASE LIMIT 1
            )
            WHERE brand_id IS NULL AND brand IS NOT NULL AND TRIM(brand) <> '';
            """, transaction);
        transaction.Commit();
    }

    private static void EnsureColumn(SqliteConnection connection, string tableName, string columnName, string definition)
    {
        if (HasColumn(connection, tableName, columnName)) return;
        Execute(connection, $"ALTER TABLE {tableName} ADD COLUMN {columnName} {definition};");
    }

    private static bool TableExists(SqliteConnection connection, string tableName)
    {
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = @name;";
        command.Parameters.AddWithValue("@name", tableName);
        return Convert.ToInt64(command.ExecuteScalar() ?? 0L) > 0;
    }

    private static bool HasColumn(SqliteConnection connection, string tableName, string columnName)
    {
        if (!TableExists(connection, tableName)) return false;

        using var infoCommand = connection.CreateCommand();
        infoCommand.CommandText = $"PRAGMA table_info({tableName});";
        using var reader = infoCommand.ExecuteReader();
        while (reader.Read())
        {
            if (string.Equals(reader.GetString(1), columnName, StringComparison.OrdinalIgnoreCase)) return true;
        }
        return false;
    }

    private static void Execute(SqliteConnection connection, string sql, SqliteTransaction? transaction = null)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }
}
