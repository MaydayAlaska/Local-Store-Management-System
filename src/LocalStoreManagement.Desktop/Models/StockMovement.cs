using System.Globalization;

namespace LocalStoreManagement.Desktop.Models;

public enum StockMovementKind
{
    Incoming,
    Outgoing,
    Adjustment
}

public sealed record StockMovement(
    long Id,
    long ProductId,
    string Sku,
    string? Barcode,
    string ProductName,
    string? Brand,
    string? Category,
    StockMovementKind Kind,
    long QuantityDelta,
    string? Note,
    DateTimeOffset CreatedAtUtc,
    long StockAfter)
{
    public string TypeDisplay => Kind switch
    {
        StockMovementKind.Incoming => "Carico",
        StockMovementKind.Outgoing => "Scarico",
        StockMovementKind.Adjustment => "Rettifica",
        _ => "Movimento"
    };

    public string QuantityDisplay => QuantityDelta > 0
        ? $"+{QuantityDelta}"
        : QuantityDelta.ToString(CultureInfo.InvariantCulture);

    public string CreatedAtDisplay => CreatedAtUtc
        .ToLocalTime()
        .ToString("dd/MM/yyyy HH:mm", CultureInfo.CurrentCulture);
}
