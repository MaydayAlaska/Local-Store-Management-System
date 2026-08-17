using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Infrastructure;

public static class DatabaseInitializer
{
    public static void Initialize()
    {
        Directory.CreateDirectory(AppPaths.DataDirectory);

        using var connection = new SqliteConnection($"Data Source={AppPaths.DatabasePath}");
        connection.Open();

        using var command = connection.CreateCommand();
        command.CommandText = """
            PRAGMA foreign_keys = ON;
            PRAGMA journal_mode = WAL;

            CREATE TABLE IF NOT EXISTS products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sku TEXT NOT NULL UNIQUE,
                barcode TEXT UNIQUE,
                name TEXT NOT NULL,
                category TEXT,
                purchase_price_cents INTEGER,
                sale_price_cents INTEGER,
                stock_quantity INTEGER NOT NULL DEFAULT 0,
                minimum_stock INTEGER NOT NULL DEFAULT 0,
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

            CREATE TABLE IF NOT EXISTS inventory_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                status TEXT NOT NULL,
                started_at_utc TEXT NOT NULL,
                completed_at_utc TEXT
            );

            CREATE TABLE IF NOT EXISTS inventory_counts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                inventory_session_id INTEGER NOT NULL,
                product_id INTEGER NOT NULL,
                counted_quantity INTEGER NOT NULL DEFAULT 0,
                UNIQUE (inventory_session_id, product_id),
                FOREIGN KEY (inventory_session_id) REFERENCES inventory_sessions(id),
                FOREIGN KEY (product_id) REFERENCES products(id)
            );

            CREATE INDEX IF NOT EXISTS ix_products_barcode ON products(barcode);
            CREATE INDEX IF NOT EXISTS ix_stock_movements_product_id ON stock_movements(product_id);
            CREATE INDEX IF NOT EXISTS ix_inventory_counts_session_id ON inventory_counts(inventory_session_id);
            """;

        command.ExecuteNonQuery();
    }
}
