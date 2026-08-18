using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Security.Cryptography;
using System.Text;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Media.Imaging;
using LocalStoreManagement.Desktop.Infrastructure;

namespace LocalStoreManagement.Desktop.Services;

public static class ApplicationIconIntegrationService
{
    private const uint ShcneAssocChanged = 0x08000000;
    private const uint ShcnfIdList = 0x0000;

    public static void Apply(Window window, string sourceIconPath)
    {
        if (string.IsNullOrWhiteSpace(sourceIconPath) || !File.Exists(sourceIconPath))
        {
            return;
        }

        try
        {
            window.Icon = new WindowIcon(sourceIconPath);
        }
        catch
        {
            // L'icona personalizzata non deve impedire il funzionamento dell'applicazione.
        }

        if (!OperatingSystem.IsWindows())
        {
            return;
        }

        try
        {
            var shellIconPath = CreateWindowsShellIcon(sourceIconPath);
            UpdateWindowsShortcuts(shellIconPath);
        }
        catch
        {
            // L'integrazione con Explorer/Taskbar è best effort: la finestra continua a usare l'icona scelta.
        }
    }

    private static string CreateWindowsShellIcon(string sourceIconPath)
    {
        Directory.CreateDirectory(AppPaths.AssetsDirectory);

        var sourceBytes = File.ReadAllBytes(sourceIconPath);
        var hash = Convert.ToHexString(SHA256.HashData(sourceBytes))[..16];
        var destinationPath = Path.Combine(AppPaths.AssetsDirectory, $"app-shell-{hash}.ico");
        if (File.Exists(destinationPath))
        {
            return destinationPath;
        }

        if (string.Equals(Path.GetExtension(sourceIconPath), ".ico", StringComparison.OrdinalIgnoreCase))
        {
            File.Copy(sourceIconPath, destinationPath, overwrite: true);
            return destinationPath;
        }

        using var bitmap = new Bitmap(sourceIconPath);
        Bitmap? scaledBitmap = null;
        try
        {
            var sourceSize = bitmap.PixelSize;
            var maxSide = Math.Max(sourceSize.Width, sourceSize.Height);
            var scale = maxSide > 256 ? 256d / maxSide : 1d;
            var targetSize = new PixelSize(
                Math.Max(1, (int)Math.Round(sourceSize.Width * scale)),
                Math.Max(1, (int)Math.Round(sourceSize.Height * scale)));

            if (targetSize != sourceSize)
            {
                scaledBitmap = bitmap.CreateScaledBitmap(targetSize, BitmapInterpolationMode.HighQuality);
            }

            var iconBitmap = scaledBitmap ?? bitmap;
            using var pngStream = new MemoryStream();
            iconBitmap.Save(pngStream, new PngBitmapEncoderOptions());
            WritePngBackedIcon(destinationPath, pngStream.ToArray(), iconBitmap.PixelSize);
        }
        finally
        {
            scaledBitmap?.Dispose();
        }

        return destinationPath;
    }

    private static void WritePngBackedIcon(string destinationPath, byte[] pngBytes, PixelSize pixelSize)
    {
        using var stream = File.Create(destinationPath);
        using var writer = new BinaryWriter(stream, Encoding.UTF8, leaveOpen: false);

        writer.Write((ushort)0); // reserved
        writer.Write((ushort)1); // image type: icon
        writer.Write((ushort)1); // one image
        writer.Write(pixelSize.Width >= 256 ? (byte)0 : (byte)pixelSize.Width);
        writer.Write(pixelSize.Height >= 256 ? (byte)0 : (byte)pixelSize.Height);
        writer.Write((byte)0); // color count
        writer.Write((byte)0); // reserved
        writer.Write((ushort)1); // color planes
        writer.Write((ushort)32); // bits per pixel
        writer.Write((uint)pngBytes.Length);
        writer.Write((uint)22); // ICONDIR (6) + ICONDIRENTRY (16)
        writer.Write(pngBytes);
    }

    private static void UpdateWindowsShortcuts(string iconPath)
    {
        var executablePath = Environment.ProcessPath;
        if (string.IsNullOrWhiteSpace(executablePath) || !File.Exists(executablePath))
        {
            return;
        }

        foreach (var shortcutPath in EnumerateApplicationShortcuts())
        {
            TryUpdateShortcut(shortcutPath, executablePath, iconPath);
        }

        SHChangeNotify(ShcneAssocChanged, ShcnfIdList, IntPtr.Zero, IntPtr.Zero);
    }

    private static IEnumerable<string> EnumerateApplicationShortcuts()
    {
        var directories = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        AddDirectory(directories, Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory));

        var startMenu = Environment.GetFolderPath(Environment.SpecialFolder.StartMenu);
        if (!string.IsNullOrWhiteSpace(startMenu))
        {
            AddDirectory(directories, Path.Combine(startMenu, "Programs"));
        }

        var roamingAppData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        if (!string.IsNullOrWhiteSpace(roamingAppData))
        {
            AddDirectory(
                directories,
                Path.Combine(roamingAppData, "Microsoft", "Internet Explorer", "Quick Launch", "User Pinned", "TaskBar"));
        }

        foreach (var directory in directories)
        {
            IEnumerable<string> shortcuts;
            try
            {
                shortcuts = Directory.EnumerateFiles(directory, "*.lnk", SearchOption.AllDirectories).ToArray();
            }
            catch
            {
                continue;
            }

            foreach (var shortcut in shortcuts)
            {
                yield return shortcut;
            }
        }
    }

    private static void AddDirectory(ISet<string> directories, string? directory)
    {
        if (!string.IsNullOrWhiteSpace(directory) && Directory.Exists(directory))
        {
            directories.Add(directory);
        }
    }

    private static void TryUpdateShortcut(string shortcutPath, string executablePath, string iconPath)
    {
        object? shellLinkObject = null;
        try
        {
            shellLinkObject = new ShellLink();
            var shellLink = (IShellLinkW)shellLinkObject;
            var persistFile = (IPersistFile)shellLinkObject;
            persistFile.Load(shortcutPath, 0);

            var targetBuffer = new StringBuilder(1024);
            shellLink.GetPath(targetBuffer, targetBuffer.Capacity, IntPtr.Zero, 0);
            var shortcutTarget = targetBuffer.ToString();
            if (!PathsEqual(shortcutTarget, executablePath))
            {
                return;
            }

            shellLink.SetIconLocation(iconPath, 0);
            persistFile.Save(shortcutPath, true);
        }
        catch
        {
            // Alcuni collegamenti possono essere protetti o non essere normali Shell Link.
        }
        finally
        {
            if (shellLinkObject is not null && Marshal.IsComObject(shellLinkObject))
            {
                Marshal.FinalReleaseComObject(shellLinkObject);
            }
        }
    }

    private static bool PathsEqual(string left, string right)
    {
        try
        {
            return string.Equals(
                Path.GetFullPath(left),
                Path.GetFullPath(right),
                StringComparison.OrdinalIgnoreCase);
        }
        catch
        {
            return false;
        }
    }

    [DllImport("shell32.dll")]
    private static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);

    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    private class ShellLink
    {
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    private interface IShellLinkW
    {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cchMaxPath, IntPtr pfd, uint fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cchMaxName);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cchMaxPath);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cchMaxPath);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cchIconPath, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }
}
