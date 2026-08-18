using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;

namespace LocalStoreManagement.Desktop.Services;

public static class LabelPrinterFactory
{
    public static ILabelPrinter Create()
    {
        if (OperatingSystem.IsWindows())
        {
            return new WindowsGdiLabelPrinter();
        }

        if (OperatingSystem.IsLinux())
        {
            return new CupsLabelPrinter();
        }

        return new UnsupportedLabelPrinter();
    }
}

internal sealed class WindowsGdiLabelPrinter : ILabelPrinter
{
    private const uint PrinterEnumLocal = 0x00000002;
    private const uint PrinterEnumConnections = 0x00000004;
    private const int HorzRes = 8;
    private const int VertRes = 10;
    private const int Transparent = 1;
    private const uint Blackness = 0x00000042;
    private const uint DtCenter = 0x00000001;
    private const uint DtRight = 0x00000002;
    private const uint DtVCenter = 0x00000004;
    private const uint DtSingleLine = 0x00000020;
    private const uint DtNoPrefix = 0x00000800;
    private const uint DtEndEllipsis = 0x00008000;

    public string BackendDescription => "Windows/GDI — usa il driver della stampante installato";

    public Task<IReadOnlyList<string>> GetPrintersAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        const uint flags = PrinterEnumLocal | PrinterEnumConnections;
        EnumPrinters(flags, null, 4, IntPtr.Zero, 0, out var bytesNeeded, out _);

        if (bytesNeeded == 0)
        {
            return Task.FromResult<IReadOnlyList<string>>(Array.Empty<string>());
        }

        var buffer = Marshal.AllocHGlobal((int)bytesNeeded);
        try
        {
            if (!EnumPrinters(flags, null, 4, buffer, bytesNeeded, out _, out var returned))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Impossibile leggere l'elenco delle stampanti di Windows.");
            }

            var itemSize = Marshal.SizeOf<PrinterInfo4>();
            var printers = new List<string>((int)returned);
            for (var index = 0; index < returned; index++)
            {
                var itemPointer = IntPtr.Add(buffer, (int)index * itemSize);
                var item = Marshal.PtrToStructure<PrinterInfo4>(itemPointer);
                if (item.PrinterName == IntPtr.Zero)
                {
                    continue;
                }

                var name = Marshal.PtrToStringUni(item.PrinterName);
                if (!string.IsNullOrWhiteSpace(name))
                {
                    printers.Add(name);
                }
            }

            return Task.FromResult<IReadOnlyList<string>>(
                printers.Distinct(StringComparer.OrdinalIgnoreCase)
                    .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
                    .ToArray());
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    public Task PrintAsync(LabelPrintRequest request, CancellationToken cancellationToken = default)
        => Task.Run(() => Print(request, cancellationToken), cancellationToken);

    private static void Print(LabelPrintRequest request, CancellationToken cancellationToken)
    {
        ValidateRequest(request);

        var deviceContext = CreateDC("WINSPOOL", request.PrinterName, null, IntPtr.Zero);
        if (deviceContext == IntPtr.Zero)
        {
            throw new Win32Exception(
                Marshal.GetLastWin32Error(),
                $"Impossibile aprire la stampante '{request.PrinterName}'. Verifica che il driver sia installato e la coda sia disponibile.");
        }

        var documentInfo = new DocInfo
        {
            Size = Marshal.SizeOf<DocInfo>(),
            DocumentName = $"Etichetta {request.ProductName}"
        };

        var documentStarted = false;
        var documentCompleted = false;

        try
        {
            if (StartDoc(deviceContext, ref documentInfo) <= 0)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Windows non ha accettato il processo di stampa.");
            }

            documentStarted = true;

            for (var copy = 0; copy < request.Copies; copy++)
            {
                cancellationToken.ThrowIfCancellationRequested();

                if (StartPage(deviceContext) <= 0)
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Impossibile iniziare la pagina dell'etichetta.");
                }

                try
                {
                    DrawLabel(deviceContext, request);
                }
                finally
                {
                    if (EndPage(deviceContext) <= 0)
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "Impossibile completare la pagina dell'etichetta.");
                    }
                }
            }

            if (EndDoc(deviceContext) <= 0)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Impossibile completare il processo di stampa.");
            }

            documentCompleted = true;
        }
        finally
        {
            if (documentStarted && !documentCompleted)
            {
                AbortDoc(deviceContext);
            }

            DeleteDC(deviceContext);
        }
    }

    private static void DrawLabel(IntPtr deviceContext, LabelPrintRequest request)
    {
        var pageWidth = GetDeviceCaps(deviceContext, HorzRes);
        var pageHeight = GetDeviceCaps(deviceContext, VertRes);
        if (pageWidth <= 0 || pageHeight <= 0)
        {
            throw new InvalidOperationException("Il driver non ha restituito una dimensione di pagina valida.");
        }

        var pattern = BarcodeEncoder.Encode(request.Barcode);
        var marginX = Math.Max(8, pageWidth / 24);
        var marginY = Math.Max(6, pageHeight / 28);

        SetBkMode(deviceContext, Transparent);
        SetTextColor(deviceContext, 0);

        var nameBottom = Math.Max(marginY + 18, (int)(pageHeight * 0.20));
        DrawTextLine(
            deviceContext,
            request.ProductName,
            new RectNative(marginX, marginY, pageWidth - marginX, nameBottom),
            Math.Max(14, pageHeight / 11),
            700,
            DtSingleLine | DtVCenter | DtEndEllipsis | DtNoPrefix);

        var details = BuildDetails(request);
        if (!string.IsNullOrWhiteSpace(details))
        {
            DrawTextLine(
                deviceContext,
                details,
                new RectNative(marginX, nameBottom, pageWidth - marginX, (int)(pageHeight * 0.29)),
                Math.Max(10, pageHeight / 18),
                400,
                DtSingleLine | DtVCenter | DtEndEllipsis | DtNoPrefix);
        }

        var barcodeTop = (int)(pageHeight * 0.30);
        var barcodeHeight = Math.Max(20, (int)(pageHeight * 0.37));
        DrawBarcode(
            deviceContext,
            pattern,
            marginX,
            barcodeTop,
            pageWidth - marginX * 2,
            barcodeHeight);

        DrawTextLine(
            deviceContext,
            pattern.DisplayText,
            new RectNative(marginX, barcodeTop + barcodeHeight, pageWidth - marginX, (int)(pageHeight * 0.80)),
            Math.Max(10, pageHeight / 19),
            400,
            DtCenter | DtSingleLine | DtVCenter | DtNoPrefix);

        DrawTextLine(
            deviceContext,
            request.Sku ?? string.Empty,
            new RectNative(marginX, (int)(pageHeight * 0.80), pageWidth / 2, pageHeight - marginY),
            Math.Max(10, pageHeight / 17),
            600,
            DtSingleLine | DtVCenter | DtEndEllipsis | DtNoPrefix);

        if (request.Price.HasValue)
        {
            var priceText = request.Price.Value.ToString("C2", CultureInfo.GetCultureInfo("it-IT"));
            DrawTextLine(
                deviceContext,
                priceText,
                new RectNative(pageWidth / 2, (int)(pageHeight * 0.80), pageWidth - marginX, pageHeight - marginY),
                Math.Max(13, pageHeight / 13),
                700,
                DtRight | DtSingleLine | DtVCenter | DtNoPrefix);
        }
    }

    private static void DrawBarcode(
        IntPtr deviceContext,
        BarcodePattern pattern,
        int left,
        int top,
        int width,
        int height)
    {
        var moduleWidth = (double)width / pattern.Modules.Count;
        if (moduleWidth < 0.75)
        {
            throw new InvalidOperationException(
                "Il barcode è troppo lungo per la larghezza disponibile. Aumenta la larghezza dell'etichetta o usa un codice più corto.");
        }

        var index = 0;
        while (index < pattern.Modules.Count)
        {
            if (!pattern.Modules[index])
            {
                index++;
                continue;
            }

            var runStart = index;
            while (index < pattern.Modules.Count && pattern.Modules[index])
            {
                index++;
            }

            var x1 = left + (int)Math.Round(runStart * moduleWidth);
            var x2 = left + (int)Math.Round(index * moduleWidth);
            var barWidth = Math.Max(1, x2 - x1);

            if (!PatBlt(deviceContext, x1, top, barWidth, height, Blackness))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Errore durante il disegno del barcode.");
            }
        }
    }

    private static void DrawTextLine(
        IntPtr deviceContext,
        string text,
        RectNative rectangle,
        int fontHeight,
        int fontWeight,
        uint flags)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return;
        }

        var font = CreateFont(
            -fontHeight,
            0,
            0,
            0,
            fontWeight,
            0,
            0,
            0,
            1,
            0,
            0,
            4,
            0,
            "Arial");

        if (font == IntPtr.Zero)
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Impossibile creare il font per l'etichetta.");
        }

        var previousFont = SelectObject(deviceContext, font);
        try
        {
            DrawText(deviceContext, text, text.Length, ref rectangle, flags);
        }
        finally
        {
            if (previousFont != IntPtr.Zero)
            {
                SelectObject(deviceContext, previousFont);
            }

            DeleteObject(font);
        }
    }

    private static string BuildDetails(LabelPrintRequest request)
    {
        var parts = new[] { request.Variant, request.Size }
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Select(value => value!.Trim());

        return string.Join(" | ", parts);
    }

    private static void ValidateRequest(LabelPrintRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.PrinterName))
        {
            throw new ArgumentException("Seleziona una stampante.", nameof(request));
        }

        if (request.Copies is < 1 or > 100)
        {
            throw new ArgumentOutOfRangeException(nameof(request), "Il numero di copie deve essere compreso tra 1 e 100.");
        }

        _ = BarcodeEncoder.Encode(request.Barcode);
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct PrinterInfo4
    {
        public IntPtr PrinterName;
        public IntPtr ServerName;
        public uint Attributes;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DocInfo
    {
        public int Size;

        [MarshalAs(UnmanagedType.LPWStr)]
        public string? DocumentName;

        [MarshalAs(UnmanagedType.LPWStr)]
        public string? Output;

        [MarshalAs(UnmanagedType.LPWStr)]
        public string? DataType;

        public int Type;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RectNative
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;

        public RectNative(int left, int top, int right, int bottom)
        {
            Left = left;
            Top = top;
            Right = right;
            Bottom = bottom;
        }
    }

    [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool EnumPrinters(
        uint flags,
        string? name,
        uint level,
        IntPtr printerEnum,
        uint bufferSize,
        out uint bytesNeeded,
        out uint returned);

    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateDC(
        string driver,
        string device,
        string? output,
        IntPtr initData);

    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int StartDoc(IntPtr deviceContext, ref DocInfo documentInfo);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern int EndDoc(IntPtr deviceContext);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern int AbortDoc(IntPtr deviceContext);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern int StartPage(IntPtr deviceContext);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern int EndPage(IntPtr deviceContext);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern bool DeleteDC(IntPtr deviceContext);

    [DllImport("gdi32.dll")]
    private static extern int GetDeviceCaps(IntPtr deviceContext, int index);

    [DllImport("gdi32.dll")]
    private static extern int SetBkMode(IntPtr deviceContext, int mode);

    [DllImport("gdi32.dll")]
    private static extern uint SetTextColor(IntPtr deviceContext, uint color);

    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateFont(
        int height,
        int width,
        int escapement,
        int orientation,
        int weight,
        uint italic,
        uint underline,
        uint strikeOut,
        uint charSet,
        uint outputPrecision,
        uint clipPrecision,
        uint quality,
        uint pitchAndFamily,
        string faceName);

    [DllImport("gdi32.dll")]
    private static extern IntPtr SelectObject(IntPtr deviceContext, IntPtr objectHandle);

    [DllImport("gdi32.dll")]
    private static extern bool DeleteObject(IntPtr objectHandle);

    [DllImport("gdi32.dll", SetLastError = true)]
    private static extern bool PatBlt(
        IntPtr deviceContext,
        int x,
        int y,
        int width,
        int height,
        uint operation);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int DrawText(
        IntPtr deviceContext,
        string text,
        int textLength,
        ref RectNative rectangle,
        uint format);
}

internal sealed class CupsLabelPrinter : ILabelPrinter
{
    public string BackendDescription => "Linux/CUPS — invio PDF alla coda tramite il comando lp";

    public async Task<IReadOnlyList<string>> GetPrintersAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await RunProcessAsync("lpstat", new[] { "-a" }, cancellationToken);
            if (result.ExitCode != 0)
            {
                return Array.Empty<string>();
            }

            return result.StandardOutput
                .Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(line => line.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault())
                .Where(name => !string.IsNullOrWhiteSpace(name))
                .Select(name => name!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
                .ToArray();
        }
        catch (Win32Exception)
        {
            return Array.Empty<string>();
        }
    }

    public async Task PrintAsync(LabelPrintRequest request, CancellationToken cancellationToken = default)
    {
        ValidateRequest(request);

        var temporaryPath = Path.Combine(
            Path.GetTempPath(),
            $"local-store-label-{Guid.NewGuid():N}.pdf");

        try
        {
            var pdf = LabelPdfBuilder.Build(request);
            await File.WriteAllBytesAsync(temporaryPath, pdf, cancellationToken);

            var arguments = new[]
            {
                "-d", request.PrinterName,
                "-n", request.Copies.ToString(CultureInfo.InvariantCulture),
                "-o", "fit-to-page",
                "-o", "job-sheets=none",
                temporaryPath
            };

            ProcessResult result;
            try
            {
                result = await RunProcessAsync("lp", arguments, cancellationToken);
            }
            catch (Win32Exception ex)
            {
                throw new InvalidOperationException(
                    "Il comando 'lp' non è disponibile. Installa/configura CUPS e il driver della stampante BIXOLON.",
                    ex);
            }

            if (result.ExitCode != 0)
            {
                var detail = string.IsNullOrWhiteSpace(result.StandardError)
                    ? result.StandardOutput
                    : result.StandardError;

                throw new InvalidOperationException($"CUPS ha rifiutato la stampa: {detail.Trim()}");
            }
        }
        finally
        {
            try
            {
                if (File.Exists(temporaryPath))
                {
                    File.Delete(temporaryPath);
                }
            }
            catch
            {
                // Il file temporaneo verrà ripulito dal sistema operativo.
            }
        }
    }

    private static void ValidateRequest(LabelPrintRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.PrinterName))
        {
            throw new ArgumentException("Seleziona una stampante.", nameof(request));
        }

        if (request.Copies is < 1 or > 100)
        {
            throw new ArgumentOutOfRangeException(nameof(request), "Il numero di copie deve essere compreso tra 1 e 100.");
        }

        _ = BarcodeEncoder.Encode(request.Barcode);
    }

    private static async Task<ProcessResult> RunProcessAsync(
        string fileName,
        IEnumerable<string> arguments,
        CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = fileName,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }

        using var process = new Process { StartInfo = startInfo };
        process.Start();

        var standardOutputTask = process.StandardOutput.ReadToEndAsync();
        var standardErrorTask = process.StandardError.ReadToEndAsync();

        await process.WaitForExitAsync(cancellationToken);

        return new ProcessResult(
            process.ExitCode,
            await standardOutputTask,
            await standardErrorTask);
    }

    private sealed record ProcessResult(
        int ExitCode,
        string StandardOutput,
        string StandardError);
}

internal sealed class UnsupportedLabelPrinter : ILabelPrinter
{
    public string BackendDescription => "Stampa non supportata su questo sistema operativo";

    public Task<IReadOnlyList<string>> GetPrintersAsync(CancellationToken cancellationToken = default)
        => Task.FromResult<IReadOnlyList<string>>(Array.Empty<string>());

    public Task PrintAsync(LabelPrintRequest request, CancellationToken cancellationToken = default)
        => Task.FromException(new PlatformNotSupportedException(
            "La stampa etichette è supportata su Windows e Linux."));
}
