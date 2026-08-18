using LocalStoreManagement.Desktop.Infrastructure;
using LocalStoreManagement.Desktop.Models;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Data;

public sealed class CategoryRepository
{
    public IReadOnlyList<Category> GetAll()
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT
                c.id,
                c.name,
                COUNT(p.id) AS product_count
            FROM categories c
            LEFT JOIN products p ON p.category_id = c.id
            GROUP BY c.id, c.name
            ORDER BY c.name COLLATE NOCASE, c.id;
            """;

        using var reader = command.ExecuteReader();
        var categories = new List<Category>();
        while (reader.Read())
        {
            categories.Add(new Category(
                reader.GetInt64(0),
                reader.GetString(1),
                reader.GetInt64(2)));
        }

        return categories;
    }

    public Category? GetById(long id)
    {
        using var connection = OpenConnection();
        using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT
                c.id,
                c.name,
                COUNT(p.id) AS product_count
            FROM categories c
            LEFT JOIN products p ON p.category_id = c.id
            WHERE c.id = @id
            GROUP BY c.id, c.name;
            """;
        command.Parameters.AddWithValue("@id", id);

        using var reader = command.ExecuteReader();
        return reader.Read()
            ? new Category(reader.GetInt64(0), reader.GetString(1), reader.GetInt64(2))
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
            INSERT INTO categories (id, name)
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
            UPDATE categories
            SET name = @name
            WHERE id = @id;
            """;
        command.Parameters.AddWithValue("@id", id);
        command.Parameters.AddWithValue("@name", normalizedName);

        if (command.ExecuteNonQuery() == 0)
        {
            throw new InvalidOperationException("La categoria non esiste più.");
        }
    }

    public void DeleteAndReassign(long categoryId, long? targetCategoryId)
    {
        if (targetCategoryId == categoryId)
        {
            throw new InvalidOperationException("La categoria di destinazione deve essere diversa da quella eliminata.");
        }

        using var connection = OpenConnection();
        using var transaction = connection.BeginTransaction();

        if (targetCategoryId.HasValue)
        {
            using var targetCommand = connection.CreateCommand();
            targetCommand.Transaction = transaction;
            targetCommand.CommandText = "SELECT COUNT(*) FROM categories WHERE id = @id;";
            targetCommand.Parameters.AddWithValue("@id", targetCategoryId.Value);
            var exists = Convert.ToInt64(targetCommand.ExecuteScalar() ?? 0L) > 0;
            if (!exists)
            {
                throw new InvalidOperationException("La categoria di destinazione non esiste più.");
            }
        }

        using (var reassignCommand = connection.CreateCommand())
        {
            reassignCommand.Transaction = transaction;
            reassignCommand.CommandText = """
                UPDATE products
                SET category_id = @targetCategoryId
                WHERE category_id = @categoryId;
                """;
            reassignCommand.Parameters.AddWithValue("@categoryId", categoryId);
            reassignCommand.Parameters.AddWithValue(
                "@targetCategoryId",
                targetCategoryId.HasValue ? targetCategoryId.Value : DBNull.Value);
            reassignCommand.ExecuteNonQuery();
        }

        using (var deleteCommand = connection.CreateCommand())
        {
            deleteCommand.Transaction = transaction;
            deleteCommand.CommandText = "DELETE FROM categories WHERE id = @id;";
            deleteCommand.Parameters.AddWithValue("@id", categoryId);
            if (deleteCommand.ExecuteNonQuery() == 0)
            {
                throw new InvalidOperationException("La categoria non esiste più.");
            }
        }

        transaction.Commit();
    }

    private static long GetSmallestAvailableId(SqliteConnection connection, SqliteTransaction transaction)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = "SELECT id FROM categories ORDER BY id;";

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
            throw new ArgumentException("Il nome della categoria è obbligatorio.", nameof(name));
        }

        return normalizedName;
    }

    private static SqliteConnection OpenConnection()
        => DatabaseConnectionFactory.Open();
}
