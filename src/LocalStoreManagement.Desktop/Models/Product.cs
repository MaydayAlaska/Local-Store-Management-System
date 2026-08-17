using System.Globalization;

namespace LocalStoreManagement.Desktop.Models;

public sealed record Product(
    long Id,
    string Sku,
    string? Barcode,
    string Name,
    string? Category,
    string? Brand,
    string? Variant,
    string? Size,
    long? PurchasePriceCents,
    long? SalePriceCents,
    string? Notes,
    bool IsActive,
    long StockQuantity)
{
    public string SalePriceDisplay => FormatMoney(SalePriceCents);

    public string PurchasePriceDisplay => FormatMoney(PurchasePriceCents);

    public string StatusDisplay => IsActive ? "Attivo" : "Disattivato";

    public string DetailsDisplay
    {
        get
        {
            var details = new List<string>();

            if (!string.IsNullOrWhiteSpace(Variant))
            {
                details.Add($"Variante: {Variant}");
            }

            if (!string.IsNullOrWhiteSpace(Size))
            {
                details.Add($"Taglia: {Size}");
            }

            return details.Count == 0 ? "—" : string.Join("  •  ", details);
        }
    }

    private static string FormatMoney(long? cents)
    {
        return cents.HasValue
            ? (cents.Value / 100m).ToString("C", CultureInfo.CurrentCulture)
            : "—";
    }
}

public sealed record ProductDraft(
    long? Id,
    string Sku,
    string? Barcode,
    string Name,
    string? Category,
    string? Brand,
    string? Variant,
    string? Size,
    long? PurchasePriceCents,
    long? SalePriceCents,
    string? Notes,
    bool IsActive);
