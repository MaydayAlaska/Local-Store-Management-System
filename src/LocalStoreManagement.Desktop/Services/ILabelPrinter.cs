namespace LocalStoreManagement.Desktop.Services;

public interface ILabelPrinter
{
    Task PrintAsync(LabelPrintRequest request, CancellationToken cancellationToken = default);
}

public sealed record LabelPrintRequest(
    string ProductName,
    string Barcode,
    string? Sku,
    decimal? Price,
    int Copies = 1);
