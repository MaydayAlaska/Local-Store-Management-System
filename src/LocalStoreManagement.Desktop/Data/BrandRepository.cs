using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Data;

public sealed class BrandRepository
{
    public IReadOnlyList<Brand> GetAll()
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT
                b.id,
                b.name,
                COUNT(p.id) AS product_count
            FROM brands b
            LEFT JOIN products p ON p.brand_id = b.id
            GROUP BY b.id, b.name
            ORDER BY b.name COLLATE NOCASE, b.id;
            """;

        using var reader = command.ExecuteReader();
        var brands = new List<Brand>();
        while (reader.Read())
        {
            brands.Add(new Brand(
                reader.GetInt64(0),
                reader.GetString(1),
                reader.GetInt64(2)));
        }

        return brands;
    }

    public Brand? GetById(long id)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT
                b.id,
                b.name,
                COUNT(p.id) AS product_count
            FROM brands b
            LEFT JOIN products p ON p.brand_id = b.id
            WHERE b.id = @id
            GROUP BY b.id, b.name;
            """;
        command.Parameters.AddWithValue("@id", id);

        using var reader = command.ExecuteReader();
        return reader.Read()
            ? new Brand(reader.GetInt64(0), reader.GetString(1), reader.GetInt64(2))
            : null;
    }

    public long Create(string name)
    {
        var normalizedName = NormalizeName(name);

        using var connection = OpenConnection();
        using var transaction = connection.BeginTransaction();
        var id = GetSmallestAvailableId(connection, transaction);

        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = """
            INSERT INTO brands (id, name)
            VALUES (@id, @name);
            """;
        command.Parameters.AddWithValue("@id", id);
        command.Parameters.AddWithValue("@name", normalizedName);
        command.ExecuteNonQuery();

        transaction.Commit();
        return id;
    }

    public void Rename(long id, string name)
    {
        var normalizedName = NormalizeName(name);

        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            UPDATE brands
            SET name = @name
            WHERE id = @id;
            """;
        command.Parameters.AddWithValue("@id", id);
        command.Parameters.AddWithValue("@name", normalizedName);

        if (command.ExecuteNonQuery() == 0)
        {
            throw new InvalidOperationException("La marca non esiste più.");
        }
    }

    public void DeleteAndReassign(long brandId, long? targetBrandId)
    {
        if (targetBrandId == brandId)
        {
            throw new InvalidOperationException("La marca di destinazione deve essere diversa da quella eliminata.");
        }

        using var connection = OpenConnection();
        using var transaction = connection.BeginTransaction();

        if (targetBrandId.HasValue)
        {
            using var targetCommand = connection.CreateCommand();
            targetCommand.Transaction = transaction;
            targetCommand.CommandText = "SELECT COUNT(*) FROM brands WHERE id = @id;";
            targetCommand.Parameters.AddWithValue("@id", targetBrandId.Value);
            var exists = Convert.ToInt64(targetCommand.ExecuteScalar() ?? 0L) > 0;
            if (!exists)
            {
                throw new InvalidOperationException("La marca di destinazione non esiste più.");
            }
        }

        using (var reassignCommand = connection.CreateCommand())
        {
            reassignCommand.Transaction = transaction;
            reassignCommand.CommandText = """
                UPDATE products
                SET brand_id = @targetBrandId
                WHERE brand_id = @brandId;
                """;
            reassignCommand.Parameters.AddWithValue("@brandId", brandId);
            reassignCommand.Parameters.AddWithValue(
                "@targetBrandId",
                targetBrandId.HasValue ? targetBrandId.Value : DBNull.Value);
            reassignCommand.ExecuteNonQuery();
        }

        using (var deleteCommand = connection.CreateCommand())
        {
            deleteCommand.Transaction = transaction;
            deleteCommand.CommandText = "DELETE FROM brands WHERE id = @id;";
            deleteCommand.Parameters.AddWithValue("@id", brandId);
            if (deleteCommand.ExecuteNonQuery() == 0)
            {
                throw new InvalidOperationException("La marca non esiste più.");
            }
        }

        transaction.Commit();
    }

    private static long GetSmallestAvailableId(SqliteConnection connection, SqliteTransaction transaction)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = "SELECT id FROM brands ORDER BY id;";

        using var reader = command.ExecuteReader();
        var expected = 1L;
        while (reader.Read())
        {
            var id = reader.GetInt64(0);
            if (id > expected)
            {
                return expected;
            }

            if (id == expected)
            {
                expected++;
            }
        }

        return expected;
    }

    private static string NormalizeName(string name)
    {
        var normalizedName = name?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(normalizedName))
        {
            throw new ArgumentException("Il nome della marca è obbligatorio.", nameof(name));
        }

        return normalizedName;
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
}
