using System.Globalization;
using System.Text;

namespace LocalStoreManagement.Desktop.Services;

internal static class LabelPdfBuilder
{
    private const double PointsPerMillimeter = 72.0 / 25.4;

    public static byte[] Build(LabelPrintRequest request)
    {
        if (request.WidthMm is < 20 or > 120)
        {
            throw new ArgumentOutOfRangeException(nameof(request), "La larghezza etichetta deve essere compresa tra 20 e 120 mm.");
        }

        if (request.HeightMm is < 15 or > 200)
        {
            throw new ArgumentOutOfRangeException(nameof(request), "L'altezza etichetta deve essere compresa tra 15 e 200 mm.");
        }

        var pattern = BarcodeEncoder.Encode(request.Barcode);
        var width = request.WidthMm * PointsPerMillimeter;
        var height = request.HeightMm * PointsPerMillimeter;
        var content = BuildContent(request, pattern, width, height);

        return BuildPdf(width, height, content);
    }

    private static string BuildContent(
        LabelPrintRequest request,
        BarcodePattern pattern,
        double width,
        double height)
    {
        var culture = CultureInfo.GetCultureInfo("it-IT");
        var builder = new StringBuilder();

        builder.AppendLine("0 0 0 rg");
        builder.AppendLine("0 0 0 RG");

        var marginX = width * 0.055;
        var titleSize = Math.Clamp(height * 0.105, 7.5, 13.5);
        var smallSize = Math.Clamp(height * 0.065, 5.5, 9.5);
        var priceSize = Math.Clamp(height * 0.12, 8.5, 15.5);

        var productName = Truncate(request.ProductName, 42);
        AppendText(
            builder,
            productName,
            marginX,
            height - titleSize - height * 0.07,
            titleSize,
            "F2");

        var details = string.Join(
            " | ",
            new[] { request.Variant, request.Size }
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Select(value => value!.Trim()));

        if (!string.IsNullOrWhiteSpace(details))
        {
            AppendText(
                builder,
                Truncate(details, 44),
                marginX,
                height - titleSize - smallSize - height * 0.12,
                smallSize,
                "F1");
        }

        var barcodeLeft = marginX;
        var barcodeWidth = width - marginX * 2;
        var barcodeBottom = height * 0.28;
        var barcodeHeight = height * 0.35;
        AppendBarcode(builder, pattern, barcodeLeft, barcodeBottom, barcodeWidth, barcodeHeight);

        var barcodeTextSize = Math.Clamp(height * 0.065, 5.5, 9.0);
        var barcodeTextWidth = ApproximateTextWidth(pattern.DisplayText, barcodeTextSize);
        AppendText(
            builder,
            pattern.DisplayText,
            Math.Max(marginX, (width - barcodeTextWidth) / 2),
            height * 0.19,
            barcodeTextSize,
            "F1");

        if (!string.IsNullOrWhiteSpace(request.Sku))
        {
            AppendText(
                builder,
                Truncate(request.Sku!, 24),
                marginX,
                height * 0.07,
                smallSize,
                "F2");
        }

        if (request.Price.HasValue)
        {
            var priceText = $"EUR {request.Price.Value.ToString("N2", culture)}";
            var priceWidth = ApproximateTextWidth(priceText, priceSize);
            AppendText(
                builder,
                priceText,
                Math.Max(marginX, width - marginX - priceWidth),
                height * 0.055,
                priceSize,
                "F2");
        }

        return builder.ToString();
    }

    private static void AppendBarcode(
        StringBuilder builder,
        BarcodePattern pattern,
        double left,
        double bottom,
        double width,
        double height)
    {
        var moduleWidth = width / pattern.Modules.Count;
        if (moduleWidth < 0.35)
        {
            throw new InvalidOperationException(
                "Il barcode è troppo lungo per la larghezza dell'etichetta. Aumenta la larghezza o usa un codice più corto.");
        }

        var index = 0;
        while (index < pattern.Modules.Count)
        {
            if (!pattern.Modules[index])
            {
                index++;
                continue;
            }

            var start = index;
            while (index < pattern.Modules.Count && pattern.Modules[index])
            {
                index++;
            }

            var x = left + start * moduleWidth;
            var barWidth = Math.Max(moduleWidth * (index - start), 0.5);

            builder.Append(Format(x)).Append(' ')
                .Append(Format(bottom)).Append(' ')
                .Append(Format(barWidth)).Append(' ')
                .Append(Format(height))
                .AppendLine(" re f");
        }
    }

    private static void AppendText(
        StringBuilder builder,
        string text,
        double x,
        double y,
        double fontSize,
        string fontName)
    {
        builder.Append("BT /")
            .Append(fontName)
            .Append(' ')
            .Append(Format(fontSize))
            .Append(" Tf ")
            .Append(Format(x))
            .Append(' ')
            .Append(Format(y))
            .Append(" Td (")
            .Append(EscapePdfText(text))
            .AppendLine(") Tj ET");
    }

    private static byte[] BuildPdf(double width, double height, string content)
    {
        var encoding = Encoding.Latin1;
        var contentBytes = encoding.GetBytes(content);

        var objects = new Dictionary<int, byte[]>
        {
            [1] = encoding.GetBytes("<< /Type /Catalog /Pages 2 0 R >>"),
            [2] = encoding.GetBytes("<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
            [3] = encoding.GetBytes(
                $"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {Format(width)} {Format(height)}] " +
                "/Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>"),
            [4] = encoding.GetBytes("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"),
            [5] = encoding.GetBytes("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>"),
            [6] = BuildStreamObject(contentBytes, encoding)
        };

        using var stream = new MemoryStream();
        Write(stream, "%PDF-1.4\n%âãÏÓ\n", encoding);

        var offsets = new long[7];
        for (var objectNumber = 1; objectNumber <= 6; objectNumber++)
        {
            offsets[objectNumber] = stream.Position;
            Write(stream, $"{objectNumber} 0 obj\n", encoding);
            stream.Write(objects[objectNumber]);
            Write(stream, "\nendobj\n", encoding);
        }

        var xrefPosition = stream.Position;
        Write(stream, "xref\n0 7\n", encoding);
        Write(stream, "0000000000 65535 f \n", encoding);

        for (var objectNumber = 1; objectNumber <= 6; objectNumber++)
        {
            Write(stream, $"{offsets[objectNumber]:0000000000} 00000 n \n", encoding);
        }

        Write(
            stream,
            $"trailer\n<< /Size 7 /Root 1 0 R >>\nstartxref\n{xrefPosition}\n%%EOF\n",
            encoding);

        return stream.ToArray();
    }

    private static byte[] BuildStreamObject(byte[] contentBytes, Encoding encoding)
    {
        using var stream = new MemoryStream();
        Write(stream, $"<< /Length {contentBytes.Length} >>\nstream\n", encoding);
        stream.Write(contentBytes);
        Write(stream, "endstream", encoding);
        return stream.ToArray();
    }

    private static string EscapePdfText(string value)
    {
        var sanitized = new StringBuilder(value.Length);

        foreach (var character in value)
        {
            var current = character switch
            {
                '\r' or '\n' or '\t' => ' ',
                > (char)255 => '?',
                _ => character
            };

            if (current is '\\' or '(' or ')')
            {
                sanitized.Append('\\');
            }

            sanitized.Append(current);
        }

        return sanitized.ToString();
    }

    private static string Truncate(string value, int maximumLength)
    {
        var normalized = value.Trim();
        if (normalized.Length <= maximumLength)
        {
            return normalized;
        }

        return normalized[..Math.Max(1, maximumLength - 1)] + "…";
    }

    private static double ApproximateTextWidth(string text, double fontSize)
        => text.Length * fontSize * 0.53;

    private static string Format(double value)
        => value.ToString("0.###", CultureInfo.InvariantCulture);

    private static void Write(Stream stream, string value, Encoding encoding)
    {
        var bytes = encoding.GetBytes(value);
        stream.Write(bytes);
    }
}
