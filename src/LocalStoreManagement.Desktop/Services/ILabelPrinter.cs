namespace LocalStoreManagement.Desktop.Services;

public interface ILabelPrinter
{
    string BackendDescription { get; }

    Task<IReadOnlyList<string>> GetPrintersAsync(CancellationToken cancellationToken = default);

    Task PrintAsync(LabelPrintRequest request, CancellationToken cancellationToken = default);
}

public sealed record LabelPrintRequest(
    string PrinterName,
    string ProductName,
    string Barcode,
    string? Sku,
    string? Variant,
    string? Size,
    decimal? Price,
    int Copies,
    double WidthMm,
    double HeightMm);
