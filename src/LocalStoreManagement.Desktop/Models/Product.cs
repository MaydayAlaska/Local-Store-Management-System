using System.Globalization;

namespace LocalStoreManagement.Desktop.Models;

public sealed record Product(
    long Id,
    long ProductId,
    string Sku,
    string? Barcode,
    string Name,
    long? CategoryId,
    string? Category,
    long? BrandId,
    string? Brand,
    string? Variant,
    string? Size,
    long? PurchasePriceCents,
    long? SalePriceCents,
    string? Notes,
    bool IsActive,
    long StockQuantity,
    string? BarcodesDisplay)
{
    public string SalePriceDisplay => MoneyFormatter.Format(SalePriceCents);
    public string PurchasePriceDisplay => MoneyFormatter.Format(PurchasePriceCents);
    public string StatusDisplay => IsActive ? "Attivo" : "Disattivato";

    public string VariantDisplay
    {
        get
        {
            var details = new List<string>();
            if (!string.IsNullOrWhiteSpace(Variant)) details.Add(Variant.Trim());
            if (!string.IsNullOrWhiteSpace(Size)) details.Add($"Taglia {Size.Trim()}");
            return details.Count == 0 ? "Variante base" : string.Join(" · ", details);
        }
    }

    public string DetailsDisplay
    {
        get
        {
            var details = new List<string>();
            if (!string.IsNullOrWhiteSpace(Variant)) details.Add($"Variante: {Variant}");
            if (!string.IsNullOrWhiteSpace(Size)) details.Add($"Taglia: {Size}");
            return details.Count == 0 ? "—" : string.Join("  •  ", details);
        }
    }
}

public sealed record ProductSummary(
    long Id,
    string Name,
    long? CategoryId,
    string? Category,
    long? BrandId,
    string? Brand,
    string? Notes,
    bool IsActive,
    int VariantCount,
    long StockQuantity,
    long? MinimumSalePriceCents,
    long? MaximumSalePriceCents)
{
    // Proprietà compatibili con il template esistente della lista Prodotti.
    public string Sku => $"{VariantCount} {(VariantCount == 1 ? "variante" : "varianti")}";
    public string? Barcode => null;
    public string DetailsDisplay => "Modello prodotto";
    public string SalePriceDisplay => MoneyFormatter.FormatRange(MinimumSalePriceCents, MaximumSalePriceCents);
    public string StatusDisplay => IsActive ? "Attivo" : "Disattivato";
}

public sealed record ProductDraft(
    long? Id,
    string Name,
    long? CategoryId,
    long? BrandId,
    string? Notes,
    bool IsActive,
    IReadOnlyList<ProductVariantDraft> Variants);

public sealed record ProductVariantDraft(
    long? Id,
    string Sku,
    string? Variant,
    string? Size,
    long? PurchasePriceCents,
    long? SalePriceCents,
    bool IsActive,
    IReadOnlyList<string> Barcodes,
    long StockQuantity = 0)
{
    public string? PrimaryBarcode => Barcodes.FirstOrDefault();
    public string BarcodesDisplay => Barcodes.Count == 0 ? "—" : string.Join(" • ", Barcodes);
    public string SalePriceDisplay => MoneyFormatter.Format(SalePriceCents);

    public string VariantDisplay
    {
        get
        {
            var details = new List<string>();
            if (!string.IsNullOrWhiteSpace(Variant)) details.Add(Variant.Trim());
            if (!string.IsNullOrWhiteSpace(Size)) details.Add($"Taglia {Size.Trim()}");
            return details.Count == 0 ? "Variante base" : string.Join(" · ", details);
        }
    }

    public string StatusDisplay => IsActive ? "Attiva" : "Disattivata";
}

public sealed record ProductCodeOwner(
    long ProductId,
    long VariantId,
    string ProductName,
    string Sku,
    string? Variant,
    string? Size)
{
    public string VariantDisplay
    {
        get
        {
            var details = new List<string>();
            if (!string.IsNullOrWhiteSpace(Variant)) details.Add(Variant.Trim());
            if (!string.IsNullOrWhiteSpace(Size)) details.Add($"Taglia {Size.Trim()}");
            return details.Count == 0 ? "Variante base" : string.Join(" · ", details);
        }
    }

    public string DisplayName => $"{ProductName} — {VariantDisplay} (SKU {Sku})";
}

internal static class MoneyFormatter
{
    public static string Format(long? cents)
        => cents.HasValue
            ? (cents.Value / 100m).ToString("C", CultureInfo.CurrentCulture)
            : "—";

    public static string FormatRange(long? minimumCents, long? maximumCents)
    {
        if (!minimumCents.HasValue && !maximumCents.HasValue) return "—";
        if (minimumCents == maximumCents) return Format(minimumCents);
        return $"{Format(minimumCents)} – {Format(maximumCents)}";
    }
}
