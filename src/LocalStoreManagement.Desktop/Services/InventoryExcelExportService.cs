using System.Globalization;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using LocalStoreManagement.Desktop.Models;
using A = DocumentFormat.OpenXml.Drawing;
using Xdr = DocumentFormat.OpenXml.Drawing.Spreadsheet;

namespace LocalStoreManagement.Desktop.Services;

public sealed record InventoryExportOptions(
    string ShopName,
    string? LogoPath,
    bool IsPartial,
    string FilterSummary);

public sealed class InventoryExcelExportService
{
    private const uint DefaultStyle = 0;
    private const uint TitleStyle = 1;
    private const uint BrandStyle = 2;
    private const uint HeaderStyle = 3;
    private const uint TextStyle = 4;
    private const uint IntegerStyle = 5;
    private const uint CurrencyStyle = 6;

    public void Export(Stream output, IReadOnlyList<Product> products, InventoryExportOptions options)
    {
        ArgumentNullException.ThrowIfNull(output);
        ArgumentNullException.ThrowIfNull(products);
        ArgumentNullException.ThrowIfNull(options);

        using var document = SpreadsheetDocument.Create(output, SpreadsheetDocumentType.Workbook);
        var workbookPart = document.AddWorkbookPart();
        workbookPart.Workbook = new Workbook();

        var stylesPart = workbookPart.AddNewPart<WorkbookStylesPart>();
        stylesPart.Stylesheet = CreateStylesheet();
        stylesPart.Stylesheet.Save();

        var worksheetPart = workbookPart.AddNewPart<WorksheetPart>();
        var sheetData = new SheetData();
        var worksheet = new Worksheet(CreateColumns(), sheetData);
        worksheetPart.Worksheet = worksheet;

        var sheets = workbookPart.Workbook.AppendChild(new Sheets());
        sheets.Append(new Sheet
        {
            Id = workbookPart.GetIdOfPart(worksheetPart),
            SheetId = 1U,
            Name = options.IsPartial ? "Inventario filtrato" : "Inventario"
        });

        var mergeCells = new MergeCells();
        worksheet.InsertAfter(mergeCells, sheetData);

        var currentRow = 1U;
        var logoAdded = TryAddLogo(worksheetPart, options.LogoPath);

        AddMergedTextRow(sheetData, mergeCells, currentRow, logoAdded ? 4 : 1, 11,
            string.IsNullOrWhiteSpace(options.ShopName) ? "Negozio" : options.ShopName.Trim(), TitleStyle);
        currentRow++;

        AddMergedTextRow(sheetData, mergeCells, currentRow, logoAdded ? 4 : 1, 11,
            options.IsPartial ? "Inventario - esportazione parziale" : "Inventario completo", TextStyle);
        currentRow++;

        AddMergedTextRow(sheetData, mergeCells, currentRow, logoAdded ? 4 : 1, 11,
            $"Generato il {DateTime.Now:dd/MM/yyyy HH:mm} · {products.Count} prodotti", TextStyle);
        currentRow++;

        if (!string.IsNullOrWhiteSpace(options.FilterSummary))
        {
            AddMergedTextRow(sheetData, mergeCells, currentRow, logoAdded ? 4 : 1, 11,
                options.FilterSummary, TextStyle);
            currentRow++;
        }

        if (logoAdded && currentRow < 6)
        {
            currentRow = 6;
        }
        else
        {
            currentRow++;
        }

        if (products.Count == 0)
        {
            AddMergedTextRow(sheetData, mergeCells, currentRow, 1, 11, "Nessun prodotto da esportare.", TextStyle);
        }
        else
        {
            foreach (var brandGroup in GroupByBrand(products))
            {
                var brandName = string.IsNullOrWhiteSpace(brandGroup.Key)
                    ? "Senza marca"
                    : brandGroup.Key!;

                AddMergedTextRow(sheetData, mergeCells, currentRow, 1, 11, brandName, BrandStyle);
                currentRow++;

                AddHeaderRow(sheetData, currentRow);
                currentRow++;

                foreach (var product in brandGroup
                             .OrderBy(item => item.Name, StringComparer.CurrentCultureIgnoreCase)
                             .ThenBy(item => item.Sku, StringComparer.CurrentCultureIgnoreCase))
                {
                    AddProductRow(sheetData, currentRow, product);
                    currentRow++;
                }

                currentRow++;
            }
        }

        worksheetPart.Worksheet.Save();
        workbookPart.Workbook.Save();
    }

    private static IEnumerable<IGrouping<string?, Product>> GroupByBrand(IReadOnlyList<Product> products)
        => products
            .GroupBy(product => Normalize(product.Brand), StringComparer.CurrentCultureIgnoreCase)
            .OrderBy(group => string.IsNullOrWhiteSpace(group.Key) ? 1 : 0)
            .ThenBy(group => group.Key, StringComparer.CurrentCultureIgnoreCase);

    private static void AddProductRow(SheetData sheetData, uint rowIndex, Product product)
    {
        var row = new Row { RowIndex = rowIndex };
        row.Append(
            TextCell(rowIndex, 1, product.Sku, TextStyle),
            TextCell(rowIndex, 2, product.Barcode, TextStyle),
            TextCell(rowIndex, 3, product.Name, TextStyle),
            TextCell(rowIndex, 4, product.Category, TextStyle),
            TextCell(rowIndex, 5, product.Variant, TextStyle),
            TextCell(rowIndex, 6, product.Size, TextStyle),
            MoneyCell(rowIndex, 7, product.PurchasePriceCents),
            MoneyCell(rowIndex, 8, product.SalePriceCents),
            NumberCell(rowIndex, 9, product.StockQuantity, IntegerStyle),
            TextCell(rowIndex, 10, product.IsActive ? "Attivo" : "Disattivato", TextStyle),
            TextCell(rowIndex, 11, product.Notes, TextStyle));
        sheetData.Append(row);
    }

    private static void AddHeaderRow(SheetData sheetData, uint rowIndex)
    {
        var headers = new[]
        {
            "SKU", "Barcode", "Prodotto", "Categoria", "Variante", "Taglia",
            "Prezzo acquisto", "Prezzo vendita", "Giacenza", "Stato", "Note"
        };

        var row = new Row { RowIndex = rowIndex };
        for (var column = 1; column <= headers.Length; column++)
        {
            row.Append(TextCell(rowIndex, column, headers[column - 1], HeaderStyle));
        }

        sheetData.Append(row);
    }

    private static void AddMergedTextRow(
        SheetData sheetData,
        MergeCells mergeCells,
        uint rowIndex,
        int startColumn,
        int endColumn,
        string text,
        uint styleIndex)
    {
        var row = new Row { RowIndex = rowIndex };
        row.Append(TextCell(rowIndex, startColumn, text, styleIndex));
        sheetData.Append(row);

        if (startColumn < endColumn)
        {
            mergeCells.Append(new MergeCell
            {
                Reference = $"{CellReference(startColumn, rowIndex)}:{CellReference(endColumn, rowIndex)}"
            });
        }
    }

    private static Cell TextCell(uint rowIndex, int columnIndex, string? value, uint styleIndex)
        => new()
        {
            CellReference = CellReference(columnIndex, rowIndex),
            DataType = CellValues.InlineString,
            StyleIndex = styleIndex,
            InlineString = new InlineString(new Text(value ?? string.Empty))
        };

    private static Cell NumberCell(uint rowIndex, int columnIndex, long value, uint styleIndex)
        => new()
        {
            CellReference = CellReference(columnIndex, rowIndex),
            DataType = CellValues.Number,
            StyleIndex = styleIndex,
            CellValue = new CellValue(value.ToString(CultureInfo.InvariantCulture))
        };

    private static Cell MoneyCell(uint rowIndex, int columnIndex, long? cents)
    {
        if (!cents.HasValue)
        {
            return TextCell(rowIndex, columnIndex, string.Empty, CurrencyStyle);
        }

        var value = cents.Value / 100m;
        return new Cell
        {
            CellReference = CellReference(columnIndex, rowIndex),
            DataType = CellValues.Number,
            StyleIndex = CurrencyStyle,
            CellValue = new CellValue(value.ToString(CultureInfo.InvariantCulture))
        };
    }

    private static string CellReference(int columnIndex, uint rowIndex)
        => $"{ColumnName(columnIndex)}{rowIndex}";

    private static string ColumnName(int columnIndex)
    {
        var dividend = columnIndex;
        var columnName = string.Empty;
        while (dividend > 0)
        {
            var modulo = (dividend - 1) % 26;
            columnName = Convert.ToChar('A' + modulo) + columnName;
            dividend = (dividend - modulo) / 26;
        }

        return columnName;
    }

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static Columns CreateColumns()
        => new(
            new Column { Min = 1, Max = 1, Width = 16, CustomWidth = true },
            new Column { Min = 2, Max = 2, Width = 19, CustomWidth = true },
            new Column { Min = 3, Max = 3, Width = 34, CustomWidth = true },
            new Column { Min = 4, Max = 4, Width = 20, CustomWidth = true },
            new Column { Min = 5, Max = 5, Width = 18, CustomWidth = true },
            new Column { Min = 6, Max = 6, Width = 12, CustomWidth = true },
            new Column { Min = 7, Max = 8, Width = 15, CustomWidth = true },
            new Column { Min = 9, Max = 9, Width = 11, CustomWidth = true },
            new Column { Min = 10, Max = 10, Width = 13, CustomWidth = true },
            new Column { Min = 11, Max = 11, Width = 36, CustomWidth = true });

    private static Stylesheet CreateStylesheet()
    {
        var numberingFormats = new NumberingFormats(
            new NumberingFormat
            {
                NumberFormatId = 164U,
                FormatCode = "€ #,##0.00"
            })
        {
            Count = 1U
        };

        var fonts = new Fonts(
            new Font(new FontSize { Val = 11D }, new FontName { Val = "Calibri" }),
            new Font(new Bold(), new FontSize { Val = 16D }, new FontName { Val = "Calibri" }),
            new Font(new Bold(), new Color { Rgb = "FFFFFFFF" }, new FontSize { Val = 12D }, new FontName { Val = "Calibri" }),
            new Font(new Bold(), new Color { Rgb = "FF1F1F1F" }, new FontSize { Val = 11D }, new FontName { Val = "Calibri" }))
        {
            Count = 4U
        };

        var fills = new Fills(
            new Fill(new PatternFill { PatternType = PatternValues.None }),
            new Fill(new PatternFill { PatternType = PatternValues.Gray125 }),
            SolidFill("FF1F4E78"),
            SolidFill("FFD9EAF7"))
        {
            Count = 4U
        };

        var borders = new Borders(
            new Border(),
            new Border(
                new LeftBorder { Style = BorderStyleValues.Thin, Color = new Color { Rgb = "FFD9D9D9" } },
                new RightBorder { Style = BorderStyleValues.Thin, Color = new Color { Rgb = "FFD9D9D9" } },
                new TopBorder { Style = BorderStyleValues.Thin, Color = new Color { Rgb = "FFD9D9D9" } },
                new BottomBorder { Style = BorderStyleValues.Thin, Color = new Color { Rgb = "FFD9D9D9" } },
                new DiagonalBorder()))
        {
            Count = 2U
        };

        var cellFormats = new CellFormats(
            new CellFormat { FontId = 0U, FillId = 0U, BorderId = 0U },
            new CellFormat { FontId = 1U, FillId = 0U, BorderId = 0U, ApplyFont = true },
            new CellFormat { FontId = 2U, FillId = 2U, BorderId = 0U, ApplyFont = true, ApplyFill = true },
            new CellFormat { FontId = 3U, FillId = 3U, BorderId = 1U, ApplyFont = true, ApplyFill = true, ApplyBorder = true, Alignment = new Alignment { WrapText = true } },
            new CellFormat { FontId = 0U, FillId = 0U, BorderId = 1U, ApplyBorder = true, Alignment = new Alignment { Vertical = VerticalAlignmentValues.Top, WrapText = true } },
            new CellFormat { FontId = 0U, FillId = 0U, BorderId = 1U, ApplyBorder = true, Alignment = new Alignment { Horizontal = HorizontalAlignmentValues.Right } },
            new CellFormat { FontId = 0U, FillId = 0U, BorderId = 1U, NumberFormatId = 164U, ApplyBorder = true, ApplyNumberFormat = true, Alignment = new Alignment { Horizontal = HorizontalAlignmentValues.Right } })
        {
            Count = 7U
        };

        return new Stylesheet(numberingFormats, fonts, fills, borders, cellFormats);
    }

    private static Fill SolidFill(string rgb)
        => new(new PatternFill(
            new ForegroundColor { Rgb = rgb },
            new BackgroundColor { Indexed = 64U })
        {
            PatternType = PatternValues.Solid
        });

    private static bool TryAddLogo(WorksheetPart worksheetPart, string? logoPath)
    {
        if (string.IsNullOrWhiteSpace(logoPath) || !File.Exists(logoPath))
        {
            return false;
        }

        try
        {
            var imageType = GetImagePartType(Path.GetExtension(logoPath));
            if (imageType is null)
            {
                return false;
            }

            var drawingsPart = worksheetPart.AddNewPart<DrawingsPart>();
            var imagePart = drawingsPart.AddImagePart(imageType.Value);
            using (var logoStream = File.OpenRead(logoPath))
            {
                imagePart.FeedData(logoStream);
            }

            var relationshipId = drawingsPart.GetIdOfPart(imagePart);
            drawingsPart.WorksheetDrawing = new Xdr.WorksheetDrawing();

            const long emuPerPixel = 9525L;
            var width = 230L * emuPerPixel;
            var height = 80L * emuPerPixel;

            var picture = new Xdr.Picture(
                new Xdr.NonVisualPictureProperties(
                    new Xdr.NonVisualDrawingProperties { Id = 1U, Name = "Logo negozio" },
                    new Xdr.NonVisualPictureDrawingProperties(new A.PictureLocks { NoChangeAspect = true })),
                new Xdr.BlipFill(
                    new A.Blip { Embed = relationshipId },
                    new A.Stretch(new A.FillRectangle())),
                new Xdr.ShapeProperties(
                    new A.Transform2D(
                        new A.Offset { X = 0L, Y = 0L },
                        new A.Extents { Cx = width, Cy = height }),
                    new A.PresetGeometry(new A.AdjustValueList()) { Preset = A.ShapeTypeValues.Rectangle }));

            var anchor = new Xdr.OneCellAnchor(
                new Xdr.FromMarker(
                    new Xdr.ColumnId("0"),
                    new Xdr.ColumnOffset("0"),
                    new Xdr.RowId("0"),
                    new Xdr.RowOffset("0")),
                new Xdr.Extent { Cx = width, Cy = height },
                picture,
                new Xdr.ClientData());

            drawingsPart.WorksheetDrawing.Append(anchor);
            drawingsPart.WorksheetDrawing.Save();

            worksheetPart.Worksheet.Append(new Drawing
            {
                Id = worksheetPart.GetIdOfPart(drawingsPart)
            });

            return true;
        }
        catch
        {
            return false;
        }
    }

    private static PartTypeInfo? GetImagePartType(string extension)
        => extension.ToLowerInvariant() switch
        {
            ".png" => ImagePartType.Png,
            ".jpg" or ".jpeg" => ImagePartType.Jpeg,
            ".bmp" => ImagePartType.Bmp,
            _ => null
        };
}
