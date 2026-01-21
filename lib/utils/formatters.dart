import 'package:flutter/services.dart';

class CapitalizeFirstLetterTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Only capitalize the first letter
    String newText = newValue.text;
    if (newText.isNotEmpty) {
      newText = newText[0].toUpperCase() + newText.substring(1);
    }

    return newValue.copyWith(text: newText, selection: newValue.selection);
  }
}
