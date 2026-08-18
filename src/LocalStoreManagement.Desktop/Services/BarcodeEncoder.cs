namespace LocalStoreManagement.Desktop.Services;

public sealed record BarcodePattern(
    IReadOnlyList<bool> Modules,
    string Symbology,
    string DisplayText);

public static class BarcodeEncoder
{
    private static readonly string[] Code128Patterns =
    {
        "212222", "222122", "222221", "121223", "121322", "131222", "122213", "122312", "132212", "221213",
        "221312", "231212", "112232", "122132", "122231", "113222", "123122", "123221", "223211", "221132",
        "221231", "213212", "223112", "312131", "311222", "321122", "321221", "312212", "322112", "322211",
        "212123", "212321", "232121", "111323", "131123", "131321", "112313", "132113", "132311", "211313",
        "231113", "231311", "112133", "112331", "132131", "113123", "113321", "133121", "313121", "211331",
        "231131", "213113", "213311", "213131", "311123", "311321", "331121", "312113", "312311", "332111",
        "314111", "221411", "431111", "111224", "111422", "121124", "121421", "141122", "141221", "112214",
        "112412", "122114", "122411", "142112", "142211", "241211", "221114", "413111", "241112", "134111",
        "111242", "121142", "121241", "114212", "124112", "124211", "411212", "421112", "421211", "212141",
        "214121", "412121", "111143", "111341", "131141", "114113", "114311", "411113", "411311", "113141",
        "114131", "311141", "411131", "211412", "211214", "211232", "2331112"
    };

    private static readonly string[] EanLeftOdd =
    {
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011"
    };

    private static readonly string[] EanLeftEven =
    {
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111"
    };

    private static readonly string[] EanRight =
    {
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100"
    };

    private static readonly string[] EanParity =
    {
        "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
        "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"
    };

    public static BarcodePattern Encode(string value)
    {
        var normalized = value?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(normalized))
        {
            throw new ArgumentException("Il barcode non può essere vuoto.", nameof(value));
        }

        if (IsValidEan13(normalized))
        {
            return EncodeEan13(normalized);
        }

        return EncodeCode128B(normalized);
    }

    public static bool IsValidEan13(string value)
    {
        if (value.Length != 13 || value.Any(character => !char.IsDigit(character)))
        {
            return false;
        }

        return CalculateEan13CheckDigit(value[..12]) == value[12] - '0';
    }

    private static BarcodePattern EncodeEan13(string value)
    {
        var modules = new List<bool>(113);
        AppendQuietZone(modules, 9);
        AppendBits(modules, "101");

        var parity = EanParity[value[0] - '0'];
        for (var index = 1; index <= 6; index++)
        {
            var digit = value[index] - '0';
            AppendBits(modules, parity[index - 1] == 'L' ? EanLeftOdd[digit] : EanLeftEven[digit]);
        }

        AppendBits(modules, "01010");

        for (var index = 7; index <= 12; index++)
        {
            AppendBits(modules, EanRight[value[index] - '0']);
        }

        AppendBits(modules, "101");
        AppendQuietZone(modules, 9);

        return new BarcodePattern(modules, "EAN-13", value);
    }

    private static BarcodePattern EncodeCode128B(string value)
    {
        if (value.Length > 40)
        {
            throw new ArgumentException("Il codice è troppo lungo per un'etichetta leggibile (massimo 40 caratteri).", nameof(value));
        }

        var codes = new List<int> { 104 };
        foreach (var character in value)
        {
            if (character is < (char)32 or > (char)126)
            {
                throw new ArgumentException("Code 128 supporta in questa versione i caratteri ASCII stampabili.", nameof(value));
            }

            codes.Add(character - 32);
        }

        var checksum = 104;
        for (var index = 1; index < codes.Count; index++)
        {
            checksum += codes[index] * index;
        }

        codes.Add(checksum % 103);
        codes.Add(106);

        var modules = new List<bool>();
        AppendQuietZone(modules, 10);

        foreach (var code in codes)
        {
            AppendWidthPattern(modules, Code128Patterns[code]);
        }

        AppendQuietZone(modules, 10);
        return new BarcodePattern(modules, "Code 128", value);
    }

    private static int CalculateEan13CheckDigit(string firstTwelveDigits)
    {
        var sum = 0;
        for (var index = 0; index < firstTwelveDigits.Length; index++)
        {
            var digit = firstTwelveDigits[index] - '0';
            sum += digit * (index % 2 == 0 ? 1 : 3);
        }

        return (10 - sum % 10) % 10;
    }

    private static void AppendBits(List<bool> modules, string bits)
    {
        foreach (var bit in bits)
        {
            modules.Add(bit == '1');
        }
    }

    private static void AppendWidthPattern(List<bool> modules, string widths)
    {
        var black = true;
        foreach (var widthCharacter in widths)
        {
            var width = widthCharacter - '0';
            for (var index = 0; index < width; index++)
            {
                modules.Add(black);
            }

            black = !black;
        }
    }

    private static void AppendQuietZone(List<bool> modules, int width)
    {
        for (var index = 0; index < width; index++)
        {
            modules.Add(false);
        }
    }
}
