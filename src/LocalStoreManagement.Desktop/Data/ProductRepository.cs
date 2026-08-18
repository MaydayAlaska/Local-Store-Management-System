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
        var normalizedQuery = query?.Trim() ?? string.Empty;
        command.CommandText = VariantSelectSql + """
            WHERE @search = ''
               OR pv.sku LIKE @pattern COLLATE NOCASE
               OR p.name LIKE @pattern COLLATE NOCASE
               OR COALESCE(b.name, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(c.name, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(pv.variant, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(pv.size, '') LIKE @pattern COLLATE NOCASE
               OR EXISTS (
                    SELECT 1 FROM product_barcodes search_pb
                    WHERE search_pb.variant_id = pv.id
                      AND search_pb.barcode LIKE @pattern COLLATE NOCASE)
            ORDER BY COALESCE(b.name, '') COLLATE NOCASE,
                     p.name COLLATE NOCASE,
                     COALESCE(pv.variant, '') COLLATE NOCASE,
                     COALESCE(pv.size, '') COLLATE NOCASE,
                     pv.sku COLLATE NOCASE;
            """;
        command.Parameters.AddWithValue("@search", normalizedQuery);
        command.Parameters.AddWithValue("@pattern", $"%{normalizedQuery}%");
        return ReadProducts(command);
    }

    public IReadOnlyList<ProductSummary> SearchProducts(string? query = null)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        var normalizedQuery = query?.Trim() ?? string.Empty;
        command.CommandText = ProductSummarySelectSql + """
            WHERE @search = ''
               OR p.name LIKE @pattern COLLATE NOCASE
               OR COALESCE(b.name, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(c.name, '') LIKE @pattern COLLATE NOCASE
               OR EXISTS (
                    SELECT 1
                    FROM product_variants search_pv
                    LEFT JOIN product_barcodes search_pb ON search_pb.variant_id = search_pv.id
                    WHERE search_pv.product_id = p.id
                      AND (
                           search_pv.sku LIKE @pattern COLLATE NOCASE
                        OR COALESCE(search_pv.variant, '') LIKE @pattern COLLATE NOCASE
                        OR COALESCE(search_pv.size, '') LIKE @pattern COLLATE NOCASE
                        OR COALESCE(search_pb.barcode, '') LIKE @pattern COLLATE NOCASE))
            ORDER BY COALESCE(b.name, '') COLLATE NOCASE, p.name COLLATE NOCASE;
            """;
        command.Parameters.AddWithValue("@search", normalizedQuery);
        command.Parameters.AddWithValue("@pattern", $"%{normalizedQuery}%");

        using var reader = command.ExecuteReader();
        var products = new List<ProductSummary>();
        while (reader.Read()) products.Add(ReadProductSummary(reader));
        return products;
    }

    public ProductSummary? GetProduct(long productId)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = ProductSummarySelectSql + "WHERE p.id = @id LIMIT 1;";
        command.Parameters.AddWithValue("@id", productId);
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadProductSummary(reader) : null;
    }

    public Product? GetById(long variantId)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = VariantSelectSql + "WHERE pv.id = @id LIMIT 1;";
        command.Parameters.AddWithValue("@id", variantId);
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadProduct(reader) : null;
    }

    public IReadOnlyList<ProductVariantDraft> GetVariants(long productId)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT
                pv.id, pv.sku, pv.variant, pv.size,
                pv.purchase_price_cents, pv.sale_price_cents, pv.is_active,
                COALESCE((SELECT SUM(sm.quantity_delta) FROM stock_movements sm WHERE sm.variant_id = pv.id), 0)
            FROM product_variants pv
            WHERE pv.product_id = @productId
            ORDER BY COALESCE(pv.variant, '') COLLATE NOCASE,
                     COALESCE(pv.size, '') COLLATE NOCASE,
                     pv.sku COLLATE NOCASE;
            """;
        command.Parameters.AddWithValue("@productId", productId);

        var rows = new List<(long Id, string Sku, string? Variant, string? Size, long? Purchase, long? Sale, bool Active, long Stock)>();
        using (var reader = command.ExecuteReader())
        {
            while (reader.Read())
            {
                rows.Add((
                    reader.GetInt64(0), reader.GetString(1), GetNullableString(reader, 2), GetNullableString(reader, 3),
                    GetNullableInt64(reader, 4), GetNullableInt64(reader, 5), reader.GetInt64(6) != 0, reader.GetInt64(7)));
            }
        }

        var variants = new List<ProductVariantDraft>(rows.Count);
        foreach (var row in rows)
        {
            variants.Add(new ProductVariantDraft(
                row.Id, row.Sku, row.Variant, row.Size, row.Purchase, row.Sale, row.Active,
                GetBarcodes(connection, row.Id), row.Stock));
        }
        return variants;
    }

    public Product? FindByBarcode(string barcodeOrSku)
    {
        var code = barcodeOrSku.Trim();
        if (code.Length == 0) return null;

        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = VariantSelectSql + """
            WHERE pv.sku = @code COLLATE NOCASE
               OR EXISTS (
                    SELECT 1 FROM product_barcodes exact_pb
                    WHERE exact_pb.variant_id = pv.id AND exact_pb.barcode = @code)
            ORDER BY CASE WHEN pv.sku = @code COLLATE NOCASE THEN 1 ELSE 0 END,
                     pv.id
            LIMIT 1;
            """;
        command.Parameters.AddWithValue("@code", code);
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadProduct(reader) : null;
    }

    public ProductCodeOwner? FindBarcodeOwner(string barcode, long? excludeVariantId = null)
    {
        var normalized = barcode.Trim();
        if (normalized.Length == 0) return null;
        using var connection = OpenConnection();
        return FindBarcodeOwner(connection, null, normalized, excludeVariantId);
    }

    public ProductCodeOwner? FindSkuOwner(string sku, long? excludeVariantId = null)
    {
        var normalized = sku.Trim();
        if (normalized.Length == 0) return null;
        using var connection = OpenConnection();
        return FindSkuOwner(connection, null, normalized, excludeVariantId);
    }

    public long Count()
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM products;";
        return Convert.ToInt64(command.ExecuteScalar() ?? 0L);
    }

    public string GenerateSku()
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COALESCE(MAX(id), 0) + 1 FROM product_variants;";
        var nextId = Convert.ToInt64(command.ExecuteScalar() ?? 1L);
        return $"ART{nextId:000000}";
    }

    public long Save(ProductDraft draft)
    {
        var name = draft.Name.Trim();
        if (name.Length == 0) throw new InvalidOperationException("Il nome del prodotto è obbligatorio.");
        if (draft.Variants.Count == 0) throw new InvalidOperationException("Il prodotto deve contenere almeno una variante.");

        var variants = draft.Variants.Select(NormalizeVariant).ToList();
        ValidateLocalUniqueness(name, variants);

        using var connection = OpenConnection();
        using var transaction = connection.BeginTransaction();
        try
        {
            foreach (var variant in variants)
            {
                var skuOwner = FindSkuOwner(connection, transaction, variant.Sku, variant.Id);
                if (skuOwner is not null)
                {
                    throw new InvalidOperationException($"Lo SKU «{variant.Sku}» è già utilizzato da {skuOwner.DisplayName}.");
                }

                foreach (var barcode in variant.Barcodes)
                {
                    var owner = FindBarcodeOwner(connection, transaction, barcode, variant.Id);
                    if (owner is not null)
                    {
                        throw new InvalidOperationException($"Il barcode «{barcode}» è già utilizzato da {owner.DisplayName}.");
                    }
                }
            }

            var now = DateTimeOffset.UtcNow.ToString("O");
            var productId = SaveProductRow(connection, transaction, draft, name, now);
            foreach (var variant in variants)
            {
                var variantId = SaveVariantRow(connection, transaction, productId, variant, now);
                ReplaceBarcodes(connection, transaction, variantId, variant.Barcodes);
            }

            transaction.Commit();
            return productId;
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }

    private static long SaveProductRow(
        SqliteConnection connection,
        SqliteTransaction transaction,
        ProductDraft draft,
        string name,
        string now)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        if (draft.Id.HasValue)
        {
            command.CommandText = """
                UPDATE products
                SET name = @name,
                    category_id = @categoryId,
                    brand_id = @brandId,
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
                    name, category_id, brand_id, notes, is_active, created_at_utc, updated_at_utc)
                VALUES (@name, @categoryId, @brandId, @notes, @isActive, @createdAt, @updatedAt);
                """;
            command.Parameters.AddWithValue("@createdAt", now);
        }

        command.Parameters.AddWithValue("@name", name);
        AddNullableParameter(command, "@categoryId", draft.CategoryId);
        AddNullableParameter(command, "@brandId", draft.BrandId);
        AddNullableParameter(command, "@notes", draft.Notes);
        command.Parameters.AddWithValue("@isActive", draft.IsActive ? 1 : 0);
        command.Parameters.AddWithValue("@updatedAt", now);

        var affected = command.ExecuteNonQuery();
        if (draft.Id.HasValue)
        {
            if (affected == 0) throw new InvalidOperationException("Il prodotto da modificare non esiste più.");
            return draft.Id.Value;
        }

        using var idCommand = connection.CreateCommand();
        idCommand.Transaction = transaction;
        idCommand.CommandText = "SELECT last_insert_rowid();";
        return Convert.ToInt64(idCommand.ExecuteScalar() ?? 0L);
    }

    private static long SaveVariantRow(
        SqliteConnection connection,
        SqliteTransaction transaction,
        long productId,
        ProductVariantDraft variant,
        string now)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        if (variant.Id.HasValue)
        {
            command.CommandText = """
                UPDATE product_variants
                SET sku = @sku,
                    variant = @variant,
                    size = @size,
                    purchase_price_cents = @purchasePrice,
                    sale_price_cents = @salePrice,
                    is_active = @isActive,
                    updated_at_utc = @updatedAt
                WHERE id = @id AND product_id = @productId;
                """;
            command.Parameters.AddWithValue("@id", variant.Id.Value);
        }
        else
        {
            command.CommandText = """
                INSERT INTO product_variants (
                    product_id, sku, variant, size, purchase_price_cents, sale_price_cents,
                    is_active, created_at_utc, updated_at_utc)
                VALUES (
                    @productId, @sku, @variant, @size, @purchasePrice, @salePrice,
                    @isActive, @createdAt, @updatedAt);
                """;
            command.Parameters.AddWithValue("@createdAt", now);
        }

        command.Parameters.AddWithValue("@productId", productId);
        command.Parameters.AddWithValue("@sku", variant.Sku);
        AddNullableParameter(command, "@variant", variant.Variant);
        AddNullableParameter(command, "@size", variant.Size);
        AddNullableParameter(command, "@purchasePrice", variant.PurchasePriceCents);
        AddNullableParameter(command, "@salePrice", variant.SalePriceCents);
        command.Parameters.AddWithValue("@isActive", variant.IsActive ? 1 : 0);
        command.Parameters.AddWithValue("@updatedAt", now);

        var affected = command.ExecuteNonQuery();
        if (variant.Id.HasValue)
        {
            if (affected == 0) throw new InvalidOperationException($"La variante SKU {variant.Sku} non esiste più o non appartiene a questo prodotto.");
            return variant.Id.Value;
        }

        using var idCommand = connection.CreateCommand();
        idCommand.Transaction = transaction;
        idCommand.CommandText = "SELECT last_insert_rowid();";
        return Convert.ToInt64(idCommand.ExecuteScalar() ?? 0L);
    }

    private static void ReplaceBarcodes(
        SqliteConnection connection,
        SqliteTransaction transaction,
        long variantId,
        IReadOnlyList<string> barcodes)
    {
        using (var deleteCommand = connection.CreateCommand())
        {
            deleteCommand.Transaction = transaction;
            deleteCommand.CommandText = "DELETE FROM product_barcodes WHERE variant_id = @variantId;";
            deleteCommand.Parameters.AddWithValue("@variantId", variantId);
            deleteCommand.ExecuteNonQuery();
        }

        for (var index = 0; index < barcodes.Count; index++)
        {
            using var insertCommand = connection.CreateCommand();
            insertCommand.Transaction = transaction;
            insertCommand.CommandText = """
                INSERT INTO product_barcodes (variant_id, barcode, is_primary)
                VALUES (@variantId, @barcode, @isPrimary);
                """;
            insertCommand.Parameters.AddWithValue("@variantId", variantId);
            insertCommand.Parameters.AddWithValue("@barcode", barcodes[index]);
            insertCommand.Parameters.AddWithValue("@isPrimary", index == 0 ? 1 : 0);
            insertCommand.ExecuteNonQuery();
        }
    }

    private static void ValidateLocalUniqueness(string productName, IReadOnlyList<ProductVariantDraft> variants)
    {
        var skuMap = new Dictionary<string, ProductVariantDraft>(StringComparer.OrdinalIgnoreCase);
        var barcodeMap = new Dictionary<string, ProductVariantDraft>(StringComparer.Ordinal);

        foreach (var variant in variants)
        {
            if (variant.Sku.Length == 0) throw new InvalidOperationException("Ogni variante deve avere uno SKU.");
            if (skuMap.TryGetValue(variant.Sku, out var skuOwner) && skuOwner.Id != variant.Id)
            {
                throw new InvalidOperationException(
                    $"Lo SKU «{variant.Sku}» è usato due volte nel prodotto {productName}: {skuOwner.VariantDisplay} e {variant.VariantDisplay}.");
            }
            skuMap[variant.Sku] = variant;

            foreach (var barcode in variant.Barcodes)
            {
                if (barcodeMap.TryGetValue(barcode, out var barcodeOwner) && barcodeOwner.Id != variant.Id)
                {
                    throw new InvalidOperationException(
                        $"Il barcode «{barcode}» è già assegnato a {productName} — {barcodeOwner.VariantDisplay} (SKU {barcodeOwner.Sku}).");
                }
                barcodeMap[barcode] = variant;
            }
        }
    }

    private static ProductVariantDraft NormalizeVariant(ProductVariantDraft variant)
    {
        var barcodes = variant.Barcodes
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => value.Trim())
            .Distinct(StringComparer.Ordinal)
            .ToList();
        return variant with
        {
            Sku = variant.Sku.Trim(),
            Variant = NormalizeOptional(variant.Variant),
            Size = NormalizeOptional(variant.Size),
            Barcodes = barcodes
        };
    }

    private static ProductCodeOwner? FindBarcodeOwner(
        SqliteConnection connection,
        SqliteTransaction? transaction,
        string barcode,
        long? excludeVariantId)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            SELECT p.id, pv.id, p.name, pv.sku, pv.variant, pv.size
            FROM product_barcodes pb
            INNER JOIN product_variants pv ON pv.id = pb.variant_id
            INNER JOIN products p ON p.id = pv.product_id
            WHERE pb.barcode = @barcode
              AND (@excludeId IS NULL OR pv.id <> @excludeId)
            LIMIT 1;
            """;
        command.Parameters.AddWithValue("@barcode", barcode);
        command.Parameters.AddWithValue("@excludeId", excludeVariantId.HasValue ? excludeVariantId.Value : DBNull.Value);
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadOwner(reader) : null;
    }

    private static ProductCodeOwner? FindSkuOwner(
        SqliteConnection connection,
        SqliteTransaction? transaction,
        string sku,
        long? excludeVariantId)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            SELECT p.id, pv.id, p.name, pv.sku, pv.variant, pv.size
            FROM product_variants pv
            INNER JOIN products p ON p.id = pv.product_id
            WHERE pv.sku = @sku COLLATE NOCASE
              AND (@excludeId IS NULL OR pv.id <> @excludeId)
            LIMIT 1;
            """;
        command.Parameters.AddWithValue("@sku", sku);
        command.Parameters.AddWithValue("@excludeId", excludeVariantId.HasValue ? excludeVariantId.Value : DBNull.Value);
        using var reader = command.ExecuteReader();
        return reader.Read() ? ReadOwner(reader) : null;
    }

    private static IReadOnlyList<string> GetBarcodes(SqliteConnection connection, long variantId)
    {
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT barcode
            FROM product_barcodes
            WHERE variant_id = @variantId
            ORDER BY is_primary DESC, id;
            """;
        command.Parameters.AddWithValue("@variantId", variantId);
        using var reader = command.ExecuteReader();
        var barcodes = new List<string>();
        while (reader.Read()) barcodes.Add(reader.GetString(0));
        return barcodes;
    }

    private static IReadOnlyList<Product> ReadProducts(SqliteCommand command)
    {
        using var reader = command.ExecuteReader();
        var products = new List<Product>();
        while (reader.Read()) products.Add(ReadProduct(reader));
        return products;
    }

    private static Product ReadProduct(SqliteDataReader reader)
        => new(
            reader.GetInt64(0), reader.GetInt64(1), reader.GetString(2), GetNullableString(reader, 3), reader.GetString(4),
            GetNullableInt64(reader, 5), GetNullableString(reader, 6),
            GetNullableInt64(reader, 7), GetNullableString(reader, 8),
            GetNullableString(reader, 9), GetNullableString(reader, 10),
            GetNullableInt64(reader, 11), GetNullableInt64(reader, 12),
            GetNullableString(reader, 13), reader.GetInt64(14) != 0, reader.GetInt64(15), GetNullableString(reader, 16));

    private static ProductSummary ReadProductSummary(SqliteDataReader reader)
        => new(
            reader.GetInt64(0), reader.GetString(1),
            GetNullableInt64(reader, 2), GetNullableString(reader, 3),
            GetNullableInt64(reader, 4), GetNullableString(reader, 5),
            GetNullableString(reader, 6), reader.GetInt64(7) != 0,
            Convert.ToInt32(reader.GetInt64(8)), reader.GetInt64(9),
            GetNullableInt64(reader, 10), GetNullableInt64(reader, 11));

    private static ProductCodeOwner ReadOwner(SqliteDataReader reader)
        => new(
            reader.GetInt64(0), reader.GetInt64(1), reader.GetString(2), reader.GetString(3),
            GetNullableString(reader, 4), GetNullableString(reader, 5));

    private static string? GetNullableString(SqliteDataReader reader, int ordinal)
        => reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);

    private static long? GetNullableInt64(SqliteDataReader reader, int ordinal)
        => reader.IsDBNull(ordinal) ? null : reader.GetInt64(ordinal);

    private static string? NormalizeOptional(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

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

    private static SqliteConnection OpenConnection()
        => DatabaseConnectionFactory.Open();

    private const string VariantSelectSql = """
        SELECT
            pv.id,
            p.id AS product_id,
            pv.sku,
            (SELECT pb.barcode FROM product_barcodes pb WHERE pb.variant_id = pv.id ORDER BY pb.is_primary DESC, pb.id LIMIT 1) AS primary_barcode,
            p.name,
            p.category_id,
            c.name AS category_name,
            p.brand_id,
            b.name AS brand_name,
            pv.variant,
            pv.size,
            pv.purchase_price_cents,
            pv.sale_price_cents,
            p.notes,
            CASE WHEN p.is_active = 1 AND pv.is_active = 1 THEN 1 ELSE 0 END AS is_active,
            COALESCE((SELECT SUM(sm.quantity_delta) FROM stock_movements sm WHERE sm.variant_id = pv.id), 0) AS stock_quantity,
            (SELECT GROUP_CONCAT(pb2.barcode, ' • ') FROM product_barcodes pb2 WHERE pb2.variant_id = pv.id) AS barcodes_display
        FROM product_variants pv
        INNER JOIN products p ON p.id = pv.product_id
        LEFT JOIN categories c ON c.id = p.category_id
        LEFT JOIN brands b ON b.id = p.brand_id
        """;

    private const string ProductSummarySelectSql = """
        SELECT
            p.id,
            p.name,
            p.category_id,
            c.name AS category_name,
            p.brand_id,
            b.name AS brand_name,
            p.notes,
            p.is_active,
            (SELECT COUNT(*) FROM product_variants pv_count WHERE pv_count.product_id = p.id) AS variant_count,
            COALESCE((
                SELECT SUM(sm.quantity_delta)
                FROM product_variants pv_stock
                LEFT JOIN stock_movements sm ON sm.variant_id = pv_stock.id
                WHERE pv_stock.product_id = p.id), 0) AS stock_quantity,
            (SELECT MIN(pv_min.sale_price_cents) FROM product_variants pv_min WHERE pv_min.product_id = p.id AND pv_min.sale_price_cents IS NOT NULL) AS min_sale_price,
            (SELECT MAX(pv_max.sale_price_cents) FROM product_variants pv_max WHERE pv_max.product_id = p.id AND pv_max.sale_price_cents IS NOT NULL) AS max_sale_price
        FROM products p
        LEFT JOIN categories c ON c.id = p.category_id
        LEFT JOIN brands b ON b.id = p.brand_id
        """;
}
