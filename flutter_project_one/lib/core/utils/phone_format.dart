import 'package:flutter/services.dart';

// ================================================
// PHONE FORMAT — the one place that understands Philippine mobile numbers.
//
// THE RULE
//   Stored everywhere as   +639XXXXXXXXX     (the "+63" plus 10 digits)
//   Typed in the phone box as only the 10 digits after a fixed "+63",
//   for example            9171234567
//   Shown to people as     +63 917 123 4567
//
// A Philippine mobile number is 10 digits that start with 9. People also
// write it as 09171234567 or 639171234567, so those are accepted when typed
// or pasted and converted. Anything else is rejected.
// ================================================

class PhoneFormat {
  PhoneFormat._();

  static final RegExp _national = RegExp(r'^9\d{9}$');

  /// The 10 digits after +63 (for example 9171234567), or null if [raw]
  /// is not a Philippine mobile number. Accepts 09171234567,
  /// +639171234567, 639171234567 and 9171234567, ignoring spaces, dashes
  /// and brackets.
  static String? nationalDigits(String? raw) {
    if (raw == null) return null;

    String digits = raw.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('63')) {
      digits = digits.substring(2); // 639171234567 -> 9171234567
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1); // 09171234567  -> 9171234567
    }

    return _national.hasMatch(digits) ? digits : null;
  }

  /// +639171234567 — the form that is saved. Null if [raw] is not valid.
  static String? toE164(String? raw) {
    final String? national = nationalDigits(raw);
    return national == null ? null : '+63$national';
  }

  /// +63 917 123 4567 — the form that is shown. If [raw] is not a valid
  /// number it is returned unchanged, so nothing ever shows up blank.
  static String display(String? raw) {
    final String? national = nationalDigits(raw);
    if (national == null) return raw ?? '';
    return '+63 ${national.substring(0, 3)} ${national.substring(3, 6)} ${national.substring(6)}';
  }
}

/// For the phone box that already shows a fixed "+63".
///
///   - Letters and symbols cannot be typed (only digits stay).
///   - A COMPLETE number written another common way is converted exactly:
///         09171234567     (11 digits)  ->  9171234567
///         +63 917 123 4567 / 639171234567 (12 digits)  ->  9171234567
///   - ANYTHING ELSE is left exactly as typed, so the error message can say
///     what is wrong ("too many digits", "must start with 9"). An invalid
///     number is never quietly cut down or reshaped into one that looks
///     valid. (An earlier version trimmed everything after 10 digits.)
///   - Only absurdly long input is cut, at 13 digits; that can never be a
///     valid number, so nothing valid-looking can come out of it.
class NationalPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('639')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('09')) {
      digits = digits.substring(1);
    }

    if (digits.length > 13) {
      digits = digits.substring(0, 13);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}