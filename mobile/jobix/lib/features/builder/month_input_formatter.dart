import 'package:flutter/services.dart';

/// Numeric mobile keyboard; inserts the separator without accepting arbitrary
/// date strings. Partial values stay editable and are validated only on Save.
class MonthInputFormatter extends TextInputFormatter {
  const MonthInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var normalized = newValue.text;
    for (var i = 0; i < 10; i++) {
      normalized = normalized
          .replaceAll(String.fromCharCode(0x0660 + i), '$i')
          .replaceAll(String.fromCharCode(0x06f0 + i), '$i');
    }
    final digits = normalized.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 6 ? digits.substring(0, 6) : digits;
    final formatted = limited.length > 4
        ? '${limited.substring(0, 4)}-${limited.substring(4)}'
        : limited;
    final beforeCaret = normalized
        .substring(
          0,
          newValue.selection.extentOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'\D'), '')
        .length
        .clamp(0, limited.length);
    final caret = beforeCaret > 4 ? beforeCaret + 1 : beforeCaret;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}
