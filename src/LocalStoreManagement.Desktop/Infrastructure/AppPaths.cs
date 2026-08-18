namespace LocalStoreManagement.Desktop.Infrastructure;

public static class AppPaths
{
    private const string ApplicationFolderName = "Local Store Management System";
    private const string LegacyApplicationFolderName = "LocalStoreManagementSystem";

    public static string DataDirectory { get; } = InitializeDataDirectory();

    public static string DatabasePath { get; } = Path.Combine(DataDirectory, "store.db");

    public static string SettingsPath { get; } = Path.Combine(DataDirectory, "settings.json");

    public static string AssetsDirectory { get; } = Path.Combine(DataDirectory, "assets");

    private static string InitializeDataDirectory()
    {
        var documentsDirectory = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        if (string.IsNullOrWhiteSpace(documentsDirectory))
        {
            var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            documentsDirectory = Path.Combine(userProfile, "Documents");
        }

        var dataDirectory = Path.Combine(documentsDirectory, ApplicationFolderName);
        var dataDirectoryAlreadyExisted = Directory.Exists(dataDirectory);

        Directory.CreateDirectory(dataDirectory);
        Directory.CreateDirectory(Path.Combine(dataDirectory, "assets"));

        var databasePath = Path.Combine(dataDirectory, "store.db");
        if (!File.Exists(databasePath))
        {
            // Se il database principale è stato eliminato intenzionalmente, eventuali file WAL/SHM
            // rimasti da un arresto precedente non devono contaminare il nuovo database.
            TryDeleteFile(databasePath + "-wal");
            TryDeleteFile(databasePath + "-shm");
        }

        // La migrazione dal vecchio percorso va eseguita solo al primo utilizzo della cartella
        // Documenti. Se la cartella esiste già e store.db viene eliminato, l'utente sta chiedendo
        // di ripartire da un database nuovo: non ripristiniamo automaticamente una vecchia copia.
        if (!dataDirectoryAlreadyExisted)
        {
            MigrateLegacyDatabaseIfNeeded(dataDirectory);
        }

        return dataDirectory;
    }

    private static void MigrateLegacyDatabaseIfNeeded(string destinationDirectory)
    {
        var destinationDatabase = Path.Combine(destinationDirectory, "store.db");
        if (File.Exists(destinationDatabase))
        {
            return;
        }

        var legacyDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            LegacyApplicationFolderName);
        var legacyDatabase = Path.Combine(legacyDirectory, "store.db");

        if (!File.Exists(legacyDatabase))
        {
            return;
        }

        File.Copy(legacyDatabase, destinationDatabase, overwrite: false);

        CopySidecarIfPresent(legacyDatabase + "-wal", destinationDatabase + "-wal");
        CopySidecarIfPresent(legacyDatabase + "-shm", destinationDatabase + "-shm");
    }

    private static void CopySidecarIfPresent(string source, string destination)
    {
        if (File.Exists(source) && !File.Exists(destination))
        {
            File.Copy(source, destination, overwrite: false);
        }
    }

    private static void TryDeleteFile(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (IOException)
        {
            // La pulizia è best effort: DatabaseInitializer mostrerà l'eventuale errore reale.
        }
        catch (UnauthorizedAccessException)
        {
            // Come sopra: non blocchiamo l'avvio solo per un sidecar non eliminabile.
        }
    }
}
