import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intercetta gli scanner barcode che si presentano come tastiera HID anche
/// quando il focus non si trova nel campo di ricerca della pagina.
///
/// Se l'utente sta realmente scrivendo in un EditableText, l'input resta al
/// campo attivo e non viene intercettato.
class HidBarcodeListener extends StatefulWidget {
  const HidBarcodeListener({
    super.key,
    required this.enabled,
    required this.onBarcode,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<String> onBarcode;
  final Widget child;

  @override
  State<HidBarcodeListener> createState() => _HidBarcodeListenerState();
}

class _HidBarcodeListenerState extends State<HidBarcodeListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastCharacterAt;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent || _editableTextHasFocus()) {
      return false;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final value = _buffer.toString().trim();
      _clearBuffer();
      if (value.isEmpty) return false;
      widget.onBarcode(value);
      return true;
    }

    final character = event.character;
    if (character == null || character.isEmpty) return false;
    final rune = character.runes.first;
    if (rune < 32 || rune == 127) return false;

    final now = DateTime.now();
    if (_lastCharacterAt != null && now.difference(_lastCharacterAt!) > const Duration(milliseconds: 350)) {
      _buffer.clear();
    }
    _lastCharacterAt = now;
    _buffer.write(character);
    return true;
  }

  bool _editableTextHasFocus() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _clearBuffer() {
    _buffer.clear();
    _lastCharacterAt = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
