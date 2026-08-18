using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Data;

public sealed class ProductRepository
{
    public IReadOnlyList<Product> Search(string? query = null)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();

        var normalizedQuery = query?.Trim();
        command.CommandText = """
            SELECT
                p.id,
                p.sku,
                p.barcode,
                p.name,
                p.category_id,
                c.name AS category_name,
                p.brand,
                p.variant,
                p.size,
                p.purchase_price_cents,
                p.sale_price_cents,
                p.notes,
                p.is_active,
                COALESCE(SUM(sm.quantity_delta), 0) AS stock_quantity
            FROM products p
            LEFT JOIN categories c ON c.id = p.category_id
            LEFT JOIN stock_movements sm ON sm.product_id = p.id
            WHERE @search = ''
               OR p.sku LIKE @pattern COLLATE NOCASE
               OR COALESCE(p.barcode, '') LIKE @pattern COLLATE NOCASE
               OR p.name LIKE @pattern COLLATE NOCASE
               OR COALESCE(p.brand, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(c.name, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(p.variant, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(p.size, '') LIKE @pattern COLLATE NOCASE
            GROUP BY p.id
            ORDER BY COALESCE(p.brand, '') COLLATE NOCASE, p.name COLLATE NOCASE, p.sku COLLATE NOCASE;
            """;
        command.Parameters.AddWithValue("@search", normalizedQuery ?? string.Empty);
        command.Parameters.AddWithValue("@pattern", $"%{normalizedQuery ?? string.Empty}%");

        using var reader = command.ExecuteReader();
        var products = new List<Product>();
        while (reader.Read())
        {
            products.Add(ReadProduct(reader));
        }

        return products;
    }

    public Product? GetById(long id)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT
                p.id,
                p.sku,
                p.barcode,
                p.name,
                p.category_id,
                c.name AS category_name,
                p.brand,
                p.variant,
                p.size,
                p.purchase_price_cents,
                p.sale_price_cents,
                p.notes,
                p.is_active,
                COALESCE(SUM(sm.quantity_delta), 0) AS stock_quantity
            FROM products p
            LEFT JOIN categories c ON c.id = p.category_id
            LEFT JOIN stock_movements sm ON sm.product_id = p.id
            WHERE p.id = @id
            GROUP BY p.id;
            """;
        command.Parameters.AddWithValue("@id", id);

        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadProduct(reader) : null;
    }

    public Product? FindByBarcode(string barcode)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT
                p.id,
                p.sku,
                p.barcode,
                p.name,
                p.category_id,
                c.name AS category_name,
                p.brand,
                p.variant,
                p.size,
                p.purchase_price_cents,
                p.sale_price_cents,
                p.notes,
                p.is_active,
                COALESCE(SUM(sm.quantity_delta), 0) AS stock_quantity
            FROM products p
            LEFT JOIN categories c ON c.id = p.category_id
            LEFT JOIN stock_movements sm ON sm.product_id = p.id
            WHERE p.barcode = @barcode OR p.sku = @barcode
            GROUP BY p.id
            LIMIT 1;
            """;
        command.Parameters.AddWithValue("@barcode", barcode.Trim());

        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadProduct(reader) : null;
    }

    public long Count()
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM products;";
        return (long)(command.ExecuteScalar() ?? 0L);
    }

    public string GenerateSku()
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COALESCE(MAX(id), 0) + 1 FROM products;";
        var nextId = (long)(command.ExecuteScalar() ?? 1L);
        return $"ART{nextId:000000}";
    }

    public long Save(ProductDraft draft)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        var now = DateTimeOffset.UtcNow.ToString("O");

        if (draft.Id.HasValue)
        {
            command.CommandText = """
                UPDATE products
                SET sku = @sku,
                    barcode = @barcode,
                    name = @name,
                    category_id = @categoryId,
                    brand = @brand,
                    variant = @variant,
                    size = @size,
                    purchase_price_cents = @purchasePrice,
                    sale_price_cents = @salePrice,
                    notes = @notes,
                    is_active = @isActive,
                    updated_at_utc = @updatedAt
                WHERE id = @id;
                """;
            command.Parameters.AddWithValue("@id", draft.Id.Value);
        }
        else
        {
            command.CommandText = """
                INSERT INTO products (
                    sku, barcode, name, category_id, brand, variant, size,
                    purchase_price_cents, sale_price_cents, notes, is_active,
                    created_at_utc, updated_at_utc)
                VALUES (
                    @sku, @barcode, @name, @categoryId, @brand, @variant, @size,
                    @purchasePrice, @salePrice, @notes, @isActive,
                    @createdAt, @updatedAt);
                """;
            command.Parameters.AddWithValue("@createdAt", now);
        }

        AddNullableParameter(command, "@barcode", draft.Barcode);
        command.Parameters.AddWithValue("@sku", draft.Sku.Trim());
        command.Parameters.AddWithValue("@name", draft.Name.Trim());
        AddNullableParameter(command, "@categoryId", draft.CategoryId);
        AddNullableParameter(command, "@brand", draft.Brand);
        AddNullableParameter(command, "@variant", draft.Variant);
        AddNullableParameter(command, "@size", draft.Size);
        AddNullableParameter(command, "@purchasePrice", draft.PurchasePriceCents);
        AddNullableParameter(command, "@salePrice", draft.SalePriceCents);
        AddNullableParameter(command, "@notes", draft.Notes);
        command.Parameters.AddWithValue("@isActive", draft.IsActive ? 1 : 0);
        command.Parameters.AddWithValue("@updatedAt", now);

        command.ExecuteNonQuery();

        if (draft.Id.HasValue)
        {
            return draft.Id.Value;
        }

        command.CommandText = "SELECT last_insert_rowid();";
        command.Parameters.Clear();
        return (long)(command.ExecuteScalar() ?? 0L);
    }

    private static SqliteConnection OpenConnection()
    {
        var connection = new SqliteConnection($"Data Source={AppPaths.DatabasePath}");
        connection.Open();

        using var command = connection.CreateCommand();
        command.CommandText = "PRAGMA foreign_keys = ON;";
        command.ExecuteNonQuery();

        return connection;
    }

    private static Product ReadProduct(SqliteDataReader reader)
    {
        return new Product(
            reader.GetInt64(0),
            reader.GetString(1),
            GetNullableString(reader, 2),
            reader.GetString(3),
            GetNullableInt64(reader, 4),
            GetNullableString(reader, 5),
            GetNullableString(reader, 6),
            GetNullableString(reader, 7),
            GetNullableString(reader, 8),
            GetNullableInt64(reader, 9),
            GetNullableInt64(reader, 10),
            GetNullableString(reader, 11),
            reader.GetInt64(12) != 0,
            reader.GetInt64(13));
    }

    private static string? GetNullableString(SqliteDataReader reader, int ordinal)
        => reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);

    private static long? GetNullableInt64(SqliteDataReader reader, int ordinal)
        => reader.IsDBNull(ordinal) ? null : reader.GetInt64(ordinal);

    private static void AddNullableParameter(SqliteCommand command, string name, object? value)
    {
        object dbValue = value switch
        {
            string text when string.IsNullOrWhiteSpace(text) => DBNull.Value,
            string text => text.Trim(),
            null => DBNull.Value,
            _ => value
        };

        command.Parameters.AddWithValue(name, dbValue);
    }
}
