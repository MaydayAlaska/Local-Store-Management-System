using System.Globalization;
using LocalStoreManagement.Desktop.Models;
using MigraDoc.DocumentObjectModel;
using MigraDoc.DocumentObjectModel.Tables;
using MigraDoc.Rendering;
using PdfSharp.Fonts;

namespace LocalStoreManagement.Desktop.Services;

public sealed class InventoryPdfExportService
{
    private static readonly object FontResolverLock = new();

    public void Export(Stream output, IReadOnlyList<Product> products, InventoryExportOptions options)
    {
        ArgumentNullException.ThrowIfNull(output);
        ArgumentNullException.ThrowIfNull(products);
        ArgumentNullException.ThrowIfNull(options);

        EnsureFontResolver();

        var document = BuildDocument(products, options);
        var renderer = new PdfDocumentRenderer
        {
            Document = document
        };

        renderer.RenderDocument();
        renderer.PdfDocument.Save(output, closeStream: false);
    }

    private static Document BuildDocument(IReadOnlyList<Product> products, InventoryExportOptions options)
    {
        var document = new Document
        {
            Info =
            {
                Title = options.IsPartial ? "Inventario - esportazione parziale" : "Inventario completo",
                Subject = "Inventario negozio"
            }
        };

        var normalStyle = document.Styles["Normal"];
        normalStyle.Font.Name = InventoryPdfFontResolver.FamilyName;
        normalStyle.Font.Size = Unit.FromPoint(7.2);
        normalStyle.ParagraphFormat.SpaceAfter = Unit.FromPoint(2);

        var section = document.AddSection();
        section.PageSetup.PageFormat = PageFormat.A4;
        section.PageSetup.Orientation = Orientation.Landscape;
        section.PageSetup.TopMargin = Unit.FromCentimeter(0.8);
        section.PageSetup.BottomMargin = Unit.FromCentimeter(0.8);
        section.PageSetup.LeftMargin = Unit.FromCentimeter(0.8);
        section.PageSetup.RightMargin = Unit.FromCentimeter(0.8);

        AddHeader(section, products, options);

        if (products.Count == 0)
        {
            var empty = section.AddParagraph("Nessun prodotto da esportare.");
            empty.Format.SpaceBefore = Unit.FromPoint(8);
            return document;
        }

        foreach (var brandGroup in GroupByBrand(products))
        {
            var brandName = string.IsNullOrWhiteSpace(brandGroup.Key)
                ? "Senza marca"
                : brandGroup.Key!;

            var brandHeading = section.AddParagraph(brandName);
            brandHeading.Format.Font.Size = Unit.FromPoint(10);
            brandHeading.Format.Font.Bold = true;
            brandHeading.Format.SpaceBefore = Unit.FromPoint(8);
            brandHeading.Format.SpaceAfter = Unit.FromPoint(3);
            brandHeading.Format.KeepWithNext = true;

            var table = CreateInventoryTable(section);
            AddTableHeader(table);

            foreach (var product in brandGroup
                         .OrderBy(item => item.Name, StringComparer.CurrentCultureIgnoreCase)
                         .ThenBy(item => item.Sku, StringComparer.CurrentCultureIgnoreCase))
            {
                AddProductRow(table, product);
            }
        }

        return document;
    }

    private static void AddHeader(Section section, IReadOnlyList<Product> products, InventoryExportOptions options)
    {
        if (!string.IsNullOrWhiteSpace(options.LogoPath) && File.Exists(options.LogoPath))
        {
            try
            {
                var image = section.AddImage(options.LogoPath);
                image.LockAspectRatio = true;
                image.Width = Unit.FromCentimeter(4.2);
            }
            catch
            {
                // Un logo non leggibile non deve impedire l'esportazione dell'inventario.
            }
        }

        var shopName = section.AddParagraph(
            string.IsNullOrWhiteSpace(options.ShopName) ? "Negozio" : options.ShopName.Trim());
        shopName.Format.Font.Size = Unit.FromPoint(15);
        shopName.Format.Font.Bold = true;
        shopName.Format.SpaceBefore = Unit.FromPoint(2);
        shopName.Format.SpaceAfter = Unit.FromPoint(2);

        var title = section.AddParagraph(
            options.IsPartial ? "Inventario - esportazione parziale" : "Inventario completo");
        title.Format.Font.Size = Unit.FromPoint(10);
        title.Format.Font.Bold = true;
        title.Format.SpaceAfter = Unit.FromPoint(2);

        var generated = section.AddParagraph(
            $"Generato il {DateTime.Now:dd/MM/yyyy HH:mm} - {products.Count} prodotti");
        generated.Format.Font.Size = Unit.FromPoint(7.5);
        generated.Format.SpaceAfter = Unit.FromPoint(2);

        if (!string.IsNullOrWhiteSpace(options.FilterSummary))
        {
            var filters = section.AddParagraph(options.FilterSummary);
            filters.Format.Font.Size = Unit.FromPoint(7.5);
            filters.Format.SpaceAfter = Unit.FromPoint(5);
        }

        var footer = section.Footers.Primary.AddParagraph();
        footer.Format.Alignment = ParagraphAlignment.Center;
        footer.Format.Font.Size = Unit.FromPoint(6.5);
        footer.AddText("Pagina ");
        footer.AddPageField();
    }

    private static Table CreateInventoryTable(Section section)
    {
        var table = section.AddTable();
        table.Format.Font.Name = InventoryPdfFontResolver.FamilyName;
        table.Format.Font.Size = Unit.FromPoint(6.2);
        table.Borders.Width = Unit.FromPoint(0.35);
        table.Borders.Color = Colors.Gray;
        table.Rows.LeftIndent = Unit.Zero;

        table.AddColumn(Unit.FromCentimeter(2.1));
        table.AddColumn(Unit.FromCentimeter(2.7));
        table.AddColumn(Unit.FromCentimeter(4.2));
        table.AddColumn(Unit.FromCentimeter(2.5));
        table.AddColumn(Unit.FromCentimeter(2.1));
        table.AddColumn(Unit.FromCentimeter(1.4));
        table.AddColumn(Unit.FromCentimeter(2.0));
        table.AddColumn(Unit.FromCentimeter(2.0));
        table.AddColumn(Unit.FromCentimeter(1.3));
        table.AddColumn(Unit.FromCentimeter(1.6));
        table.AddColumn(Unit.FromCentimeter(6.1));

        return table;
    }

    private static void AddTableHeader(Table table)
    {
        var headers = new[]
        {
            "SKU", "Barcode", "Prodotto", "Categoria", "Variante", "Taglia",
            "P. acquisto", "P. vendita", "Q.tà", "Stato", "Note"
        };

        var row = table.AddRow();
        row.HeadingFormat = true;
        row.Format.Font.Bold = true;
        row.Format.Font.Size = Unit.FromPoint(6.3);
        row.Shading.Color = Colors.LightGray;
        row.VerticalAlignment = VerticalAlignment.Center;

        for (var i = 0; i < headers.Length; i++)
        {
            var alignment = i is 6 or 7 or 8
                ? ParagraphAlignment.Right
                : ParagraphAlignment.Left;
            AddCell(row.Cells[i], headers[i], alignment);
        }
    }

    private static void AddProductRow(Table table, Product product)
    {
        var row = table.AddRow();
        row.VerticalAlignment = VerticalAlignment.Top;

        AddCell(row.Cells[0], product.Sku);
        AddCell(row.Cells[1], product.Barcode);
        AddCell(row.Cells[2], product.Name);
        AddCell(row.Cells[3], product.Category);
        AddCell(row.Cells[4], product.Variant);
        AddCell(row.Cells[5], product.Size);
        AddCell(row.Cells[6], FormatMoney(product.PurchasePriceCents), ParagraphAlignment.Right);
        AddCell(row.Cells[7], FormatMoney(product.SalePriceCents), ParagraphAlignment.Right);
        AddCell(row.Cells[8], product.StockQuantity.ToString(CultureInfo.CurrentCulture), ParagraphAlignment.Right);
        AddCell(row.Cells[9], product.IsActive ? "Attivo" : "Disattivato");
        AddCell(row.Cells[10], product.Notes);
    }

    private static void AddCell(Cell cell, string? value, ParagraphAlignment alignment = ParagraphAlignment.Left)
    {
        var paragraph = cell.AddParagraph(value ?? string.Empty);
        paragraph.Format.Alignment = alignment;
        paragraph.Format.SpaceAfter = Unit.Zero;
        paragraph.Format.SpaceBefore = Unit.Zero;
    }

    private static string FormatMoney(long? cents)
        => cents.HasValue
            ? $"{cents.Value / 100m:0.00} €"
            : string.Empty;

    private static IEnumerable<IGrouping<string?, Product>> GroupByBrand(IReadOnlyList<Product> products)
        => products
            .GroupBy(product => Normalize(product.Brand), StringComparer.CurrentCultureIgnoreCase)
            .OrderBy(group => string.IsNullOrWhiteSpace(group.Key) ? 1 : 0)
            .ThenBy(group => group.Key, StringComparer.CurrentCultureIgnoreCase);

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static void EnsureFontResolver()
    {
        lock (FontResolverLock)
        {
            if (GlobalFontSettings.FontResolver is null)
            {
                GlobalFontSettings.FontResolver = new InventoryPdfFontResolver();
            }
        }
    }
}

internal sealed class InventoryPdfFontResolver : IFontResolver
{
    public const string FamilyName = "LocalStoreSans";
    private const string RegularFaceName = "LocalStoreSans-Regular";
    private const string BoldFaceName = "LocalStoreSans-Bold";

    private readonly string _regularFontPath;
    private readonly string _boldFontPath;

    public InventoryPdfFontResolver()
    {
        _regularFontPath = FindFontPath(isBold: false)
            ?? throw new InvalidOperationException(
                "Impossibile trovare un font di sistema compatibile per generare il PDF.");
        _boldFontPath = FindFontPath(isBold: true) ?? _regularFontPath;
    }

    public string DefaultFontName => FamilyName;

    public FontResolverInfo? ResolveTypeface(string familyName, bool isBold, bool isItalic)
    {
        var useBoldFace = isBold && !string.Equals(_regularFontPath, _boldFontPath, StringComparison.OrdinalIgnoreCase);
        var faceName = useBoldFace ? BoldFaceName : RegularFaceName;
        var simulateBold = isBold && !useBoldFace;
        return new FontResolverInfo(faceName, simulateBold, isItalic);
    }

    public byte[]? GetFont(string faceName)
        => faceName switch
        {
            RegularFaceName => File.ReadAllBytes(_regularFontPath),
            BoldFaceName => File.ReadAllBytes(_boldFontPath),
            _ => null
        };

    private static string? FindFontPath(bool isBold)
    {
        foreach (var path in GetFontCandidates(isBold))
        {
            if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
            {
                return path;
            }
        }

        return null;
    }

    private static IEnumerable<string> GetFontCandidates(bool isBold)
    {
        var windowsDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        if (!string.IsNullOrWhiteSpace(windowsDirectory))
        {
            var fonts = Path.Combine(windowsDirectory, "Fonts");
            if (isBold)
            {
                yield return Path.Combine(fonts, "arialbd.ttf");
                yield return Path.Combine(fonts, "segoeuib.ttf");
            }
            else
            {
                yield return Path.Combine(fonts, "arial.ttf");
                yield return Path.Combine(fonts, "segoeui.ttf");
            }
        }

        if (isBold)
        {
            yield return "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf";
            yield return "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf";
            yield return "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf";
            yield return "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf";
            yield return "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf";
        }
        else
        {
            yield return "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf";
            yield return "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf";
            yield return "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf";
            yield return "/usr/share/fonts/truetype/freefont/FreeSans.ttf";
            yield return "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf";
        }
    }
}
