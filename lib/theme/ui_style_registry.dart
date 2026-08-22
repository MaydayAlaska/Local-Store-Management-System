import 'styles/glassmorphism/glassmorphism_style.dart';
import 'ui_style.dart';

class UiStyleRegistry {
  const UiStyleRegistry._();

  static const fallbackId = GlassmorphismStyle.styleId;

  static const List<AppUiStyle> all = <AppUiStyle>[
    GlassmorphismStyle(),
  ];

  static AppUiStyle resolve(String? id) {
    final normalized = id?.trim().toLowerCase();
    for (final style in all) {
      if (style.id == normalized) return style;
    }
    return all.first;
  }
}
