using Avalonia;
using Avalonia.Controls;
using Avalonia.Media;
using LocalStoreManagement.Desktop.Services;

namespace LocalStoreManagement.Desktop.Controls;

public sealed class BarcodePreviewControl : Control
{
    public static readonly StyledProperty<string?> ValueProperty =
        AvaloniaProperty.Register<BarcodePreviewControl, string?>(nameof(Value));

    static BarcodePreviewControl()
    {
        AffectsRender<BarcodePreviewControl>(ValueProperty);
    }

    public string? Value
    {
        get => GetValue(ValueProperty);
        set => SetValue(ValueProperty, value);
    }

    public override void Render(DrawingContext context)
    {
        base.Render(context);

        context.FillRectangle(Brushes.White, new Rect(0, 0, Bounds.Width, Bounds.Height));

        if (string.IsNullOrWhiteSpace(Value) || Bounds.Width <= 0 || Bounds.Height <= 0)
        {
            return;
        }

        BarcodePattern pattern;
        try
        {
            pattern = BarcodeEncoder.Encode(Value);
        }
        catch
        {
            return;
        }

        var moduleWidth = Bounds.Width / pattern.Modules.Count;
        var barTop = Math.Max(2, Bounds.Height * 0.04);
        var barHeight = Math.Max(1, Bounds.Height - barTop * 2);

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

            var left = start * moduleWidth;
            var right = index * moduleWidth;
            context.FillRectangle(Brushes.Black, new Rect(left, barTop, Math.Max(0.5, right - left), barHeight));
        }
    }
}
