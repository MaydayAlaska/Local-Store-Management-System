using System.Text;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Infrastructure;

public static class AppLog
{
    private static readonly object SyncRoot = new();

    public static string LogDirectory => Path.Combine(AppPaths.DataDirectory, "Logs");
    public static string LogPath => Path.Combine(LogDirectory, "application.log");

    public static void Info(string context, string message)
        => Write(context, message, null);

    public static void Error(string context, Exception exception)
        => Write(context, exception.Message, exception);

    private static void Write(string context, string message, Exception? exception)
    {
        try
        {
            lock (SyncRoot)
            {
                Directory.CreateDirectory(LogDirectory);

                var builder = new StringBuilder();
                builder.Append('[')
                    .Append(DateTimeOffset.Now.ToString("O"))
                    .Append("] ")
                    .Append(context)
                    .AppendLine();
                builder.Append("Database: ").AppendLine(AppPaths.DatabasePath);
                builder.Append("Messaggio: ").AppendLine(message);

                if (exception is SqliteException sqliteException)
                {
                    builder.Append("SQLite code: ").Append(sqliteException.SqliteErrorCode)
                        .Append(" / extended: ").AppendLine(sqliteException.SqliteExtendedErrorCode.ToString());
                }

                if (exception is not null)
                {
                    builder.AppendLine(exception.ToString());
                }

                builder.AppendLine(new string('-', 80));
                File.AppendAllText(LogPath, builder.ToString());
            }
        }
        catch
        {
            // Il logging non deve mai causare a sua volta la chiusura dell'applicazione.
        }
    }
}
