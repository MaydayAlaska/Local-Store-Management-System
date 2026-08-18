using LocalStoreManagement.Desktop.Infrastructure;
using Microsoft.Data.Sqlite;

namespace LocalStoreManagement.Desktop.Services;

public sealed class DatabaseBackupService
{
    public string CreateBackup()
    {
        var backupDirectory = Path.Combine(AppPaths.DataDirectory, "Backups");
        Directory.CreateDirectory(backupDirectory);

        var timestamp = DateTime.Now.ToString("yyyyMMdd-HHmmss");
        var backupPath = Path.Combine(backupDirectory, $"store-backup-{timestamp}.db");
        var suffix = 1;
        while (File.Exists(backupPath))
        {
            backupPath = Path.Combine(backupDirectory, $"store-backup-{timestamp}-{suffix:00}.db");
            suffix++;
        }

        using var source = new SqliteConnection($"Data Source={AppPaths.DatabasePath};Mode=ReadWrite");
        using var destination = new SqliteConnection($"Data Source={backupPath};Mode=ReadWriteCreate");
        source.Open();
        destination.Open();
        source.BackupDatabase(destination);

        return backupPath;
    }
}
