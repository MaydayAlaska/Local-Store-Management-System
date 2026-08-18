namespace LocalStoreManagement.Desktop.Models;

public sealed record Brand(
    long Id,
    string Name,
    long ProductCount)
{
    public string ProductCountDisplay => ProductCount == 1
        ? "1 prodotto"
        : $"{ProductCount} prodotti";
}
