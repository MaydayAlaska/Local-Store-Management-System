using System.Globalization;
using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Data;

public sealed class StockMovementRepository
{
    public long GetCurrentStock(long productId)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT COALESCE(SUM(quantity_delta), 0)
            FROM stock_movements
            WHERE product_id = @productId;
            """;
        command.Parameters.AddWithValue("@productId", productId);
        return Convert.ToInt64(command.ExecuteScalar() ?? 0L, CultureInfo.InvariantCulture);
    }

    public long GetTotalStock()
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COALESCE(SUM(quantity_delta), 0) FROM stock_movements;";
        return Convert.ToInt64(command.ExecuteScalar() ?? 0L, CultureInfo.InvariantCulture);
    }

    public long AddMovement(long productId, StockMovementKind kind, long quantity, string? note)
    {
        using var connection = OpenConnection();
        using var transaction = connection.BeginTransaction();

        var currentStock = GetCurrentStock(connection, transaction, productId);
        string movementType;
        long quantityDelta;

        switch (kind)
        {
            case StockMovementKind.Incoming:
                if (quantity <= 0)
                {
                    throw new ArgumentOutOfRangeException(nameof(quantity), "La quantità di carico deve essere maggiore di zero.");
                }

                movementType = "IN";
                quantityDelta = quantity;
                break;

            case StockMovementKind.Outgoing:
                if (quantity <= 0)
                {
                    throw new ArgumentOutOfRangeException(nameof(quantity), "La quantità di scarico deve essere maggiore di zero.");
                }

                if (quantity > currentStock)
                {
                    throw new InvalidOperationException($"Giacenza insufficiente. Disponibili: {currentStock}.");
                }

                movementType = "OUT";
                quantityDelta = -quantity;
                break;

            case StockMovementKind.Adjustment:
                if (quantity < 0)
                {
                    throw new ArgumentOutOfRangeException(nameof(quantity), "La giacenza rettificata non può essere negativa.");
                }

                movementType = "ADJUSTMENT";
                quantityDelta = quantity - currentStock;
                if (quantityDelta == 0)
                {
                    throw new InvalidOperationException("La giacenza indicata coincide già con quella attuale.");
                }

                break;

            default:
                throw new ArgumentOutOfRangeException(nameof(kind));
        }

        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO stock_movements (
                product_id, movement_type, quantity_delta, note, created_at_utc)
            VALUES (
                @productId, @movementType, @quantityDelta, @note, @createdAtUtc);
            SELECT last_insert_rowid();
            """;
        command.Parameters.AddWithValue("@productId", productId);
        command.Parameters.AddWithValue("@movementType", movementType);
        command.Parameters.AddWithValue("@quantityDelta", quantityDelta);
        command.Parameters.AddWithValue("@note", string.IsNullOrWhiteSpace(note) ? DBNull.Value : note.Trim());
        command.Parameters.AddWithValue("@createdAtUtc", DateTimeOffset.UtcNow.ToString("O"));

        var movementId = Convert.ToInt64(command.ExecuteScalar() ?? 0L, CultureInfo.InvariantCulture);
        transaction.Commit();
        return movementId;
    }

    public IReadOnlyList<StockMovement> Search(string? query = null, int limit = 500)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        var normalizedQuery = query?.Trim() ?? string.Empty;

        command.CommandText = """
            WITH movement_rows AS (
                SELECT
                    sm.id,
                    sm.product_id,
                    p.sku,
                    p.barcode,
                    p.name,
                    p.brand,
                    p.category,
                    sm.movement_type,
                    sm.quantity_delta,
                    sm.note,
                    sm.created_at_utc,
                    SUM(sm.quantity_delta) OVER (
                        PARTITION BY sm.product_id
                        ORDER BY sm.created_at_utc, sm.id
                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                    ) AS stock_after
                FROM stock_movements sm
                INNER JOIN products p ON p.id = sm.product_id
            )
            SELECT
                id,
                product_id,
                sku,
                barcode,
                name,
                brand,
                category,
                movement_type,
                quantity_delta,
                note,
                created_at_utc,
                stock_after
            FROM movement_rows
            WHERE @search = ''
               OR sku LIKE @pattern COLLATE NOCASE
               OR COALESCE(barcode, '') LIKE @pattern COLLATE NOCASE
               OR name LIKE @pattern COLLATE NOCASE
               OR COALESCE(brand, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(category, '') LIKE @pattern COLLATE NOCASE
               OR COALESCE(note, '') LIKE @pattern COLLATE NOCASE
               OR movement_type LIKE @pattern COLLATE NOCASE
            ORDER BY created_at_utc DESC, id DESC
            LIMIT @limit;
            """;
        command.Parameters.AddWithValue("@search", normalizedQuery);
        command.Parameters.AddWithValue("@pattern", $"%{normalizedQuery}%");
        command.Parameters.AddWithValue("@limit", Math.Clamp(limit, 1, 5000));

        using var reader = command.ExecuteReader();
        var movements = new List<StockMovement>();
        while (reader.Read())
        {
            movements.Add(new StockMovement(
                reader.GetInt64(0),
                reader.GetInt64(1),
                reader.GetString(2),
                GetNullableString(reader, 3),
                reader.GetString(4),
                GetNullableString(reader, 5),
                GetNullableString(reader, 6),
                ParseKind(reader.GetString(7)),
                reader.GetInt64(8),
                GetNullableString(reader, 9),
                DateTimeOffset.Parse(reader.GetString(10), CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind),
                reader.GetInt64(11)));
        }

        return movements;
    }

    private static long GetCurrentStock(SqliteConnection connection, SqliteTransaction transaction, long productId)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            SELECT COALESCE(SUM(quantity_delta), 0)
            FROM stock_movements
            WHERE product_id = @productId;
            """;
        command.Parameters.AddWithValue("@productId", productId);
        return Convert.ToInt64(command.ExecuteScalar() ?? 0L, CultureInfo.InvariantCulture);
    }

    private static StockMovementKind ParseKind(string value) => value switch
    {
        "IN" => StockMovementKind.Incoming,
        "OUT" => StockMovementKind.Outgoing,
        "ADJUSTMENT" => StockMovementKind.Adjustment,
        _ => StockMovementKind.Adjustment
    };

    private static string? GetNullableString(SqliteDataReader reader, int ordinal)
        => reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);

    private static SqliteConnection OpenConnection()
    {
        var connection = new SqliteConnection($"Data Source={AppPaths.DatabasePath}");
        connection.Open();

        using var command = connection.CreateCommand();
        command.CommandText = "PRAGMA foreign_keys = ON;";
        command.ExecuteNonQuery();

        return connection;
    }
}
