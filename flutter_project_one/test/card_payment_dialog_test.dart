// Put this file at:  test/card_payment_dialog_test.dart
// Run with:          flutter test test/card_payment_dialog_test.dart
//
// The package name below ("flutter_project_one") is assumed from your project
// folder name. If your pubspec.yaml says something else, change the two
// imports.
//
// These tests only check logic (validators, input formatters, peso format).
// They do not build the dialog or call PayMongo. No real card data is used:
// the numbers are PayMongo's published test cards.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_one/widgets/customer/checkout/card_payment_dialog.dart';
import 'package:flutter_project_one/widgets/customer/checkout/checkout_order_summary.dart'
    show formatPeso;

// Types one character at the cursor, the way the dialog's field does:
// the digits-only filter runs first, then our formatter.
TextEditingValue _type(
    TextInputFormatter formatter, TextEditingValue current, String char) {
  final int at = current.selection.baseOffset;
  final TextEditingValue raw = TextEditingValue(
    text: current.text.substring(0, at) + char + current.text.substring(at),
    selection: TextSelection.collapsed(offset: at + 1),
  );
  final TextEditingValue digitsOnly =
      FilteringTextInputFormatter.digitsOnly.formatEditUpdate(current, raw);
  return formatter.formatEditUpdate(current, digitsOnly);
}

TextEditingValue _typeAll(TextInputFormatter formatter, String chars,
    [TextEditingValue start = TextEditingValue.empty]) {
  TextEditingValue value = start;
  for (final String ch in chars.split('')) {
    value = _type(formatter, value, ch);
  }
  return value;
}

TextEditingValue _backspace(
    TextInputFormatter formatter, TextEditingValue current) {
  final int at = current.selection.baseOffset;
  if (at == 0) return current;
  final TextEditingValue raw = TextEditingValue(
    text: current.text.substring(0, at - 1) + current.text.substring(at),
    selection: TextSelection.collapsed(offset: at - 1),
  );
  final TextEditingValue digitsOnly =
      FilteringTextInputFormatter.digitsOnly.formatEditUpdate(current, raw);
  return formatter.formatEditUpdate(current, digitsOnly);
}

void main() {
  group('CardValidators.cardNumber', () {
    test('accepts PayMongo test cards', () {
      expect(CardValidators.cardNumber('4343 4343 4343 4345'), isNull);
      expect(CardValidators.cardNumber('4571 7360 0000 0075'), isNull);
      expect(CardValidators.cardNumber('5555 4444 4444 4457'), isNull);
    });

    test('rejects a number that fails the checksum', () {
      expect(CardValidators.cardNumber('1234 5678 9012 3456'), isNotNull);
      expect(CardValidators.cardNumber('4343 4343 4343 4346'), isNotNull);
    });

    test('rejects short or empty input', () {
      expect(CardValidators.cardNumber('4343 4343 4343'), isNotNull);
      expect(CardValidators.cardNumber(''), isNotNull);
      expect(CardValidators.cardNumber(null), isNotNull);
    });
  });

  group('CardValidators.expiry (today fixed to 19 Oct 2026)', () {
    final DateTime now = DateTime(2026, 10, 19);

    test('accepts this month and later', () {
      expect(CardValidators.expiry('10/26', now: now), isNull);
      expect(CardValidators.expiry('12/27', now: now), isNull);
      expect(CardValidators.expiry('12/46', now: now), isNull);
    });

    test('rejects past dates', () {
      expect(CardValidators.expiry('09/26', now: now), 'This card has expired');
      expect(CardValidators.expiry('12/25', now: now), 'This card has expired');
    });

    test('rejects impossible months', () {
      expect(CardValidators.expiry('00/30', now: now),
          'Month must be between 01 and 12');
      expect(CardValidators.expiry('13/30', now: now),
          'Month must be between 01 and 12');
    });

    test('rejects wrong shape and far-future years', () {
      expect(CardValidators.expiry('1/27', now: now), 'Use the format MM/YY');
      expect(CardValidators.expiry('12/2', now: now), 'Use the format MM/YY');
      expect(CardValidators.expiry('', now: now), isNotNull);
      expect(CardValidators.expiry('12/47', now: now),
          'Check the expiration year');
    });
  });

  group('CardValidators.cvc', () {
    test('needs exactly 3 digits', () {
      expect(CardValidators.cvc('123'), isNull);
      expect(CardValidators.cvc('12'), isNotNull);
      expect(CardValidators.cvc('1234'), isNotNull);
      expect(CardValidators.cvc(''), isNotNull);
    });
  });

  group('CardNumberInputFormatter', () {
    final CardNumberInputFormatter f = CardNumberInputFormatter();

    test('groups digits in fours and keeps the cursor at the end', () {
      final TextEditingValue v = _typeAll(f, '4343434343434345');
      expect(v.text, '4343 4343 4343 4345');
      expect(v.selection.baseOffset, 19);
    });

    test('ignores a 17th digit', () {
      final TextEditingValue full = _typeAll(f, '4343434343434345');
      expect(_type(f, full, '1').text, '4343 4343 4343 4345');
    });

    test('paste: keeps only digits and groups them', () {
      const TextEditingValue pasted = TextEditingValue(
        text: 'abcd4343-4343',
        selection: TextSelection.collapsed(offset: 13),
      );
      final TextEditingValue digitsOnly = FilteringTextInputFormatter.digitsOnly
          .formatEditUpdate(TextEditingValue.empty, pasted);
      final TextEditingValue v =
          f.formatEditUpdate(TextEditingValue.empty, digitsOnly);
      expect(v.text, '4343 4343');
    });

    test('backspace removes one digit', () {
      const TextEditingValue full = TextEditingValue(
        text: '4343 4343 4343 4345',
        selection: TextSelection.collapsed(offset: 19),
      );
      expect(_backspace(f, full).text, '4343 4343 4343 434');
    });

    test('typing in the middle keeps the cursor after the typed digit', () {
      const TextEditingValue old = TextEditingValue(
        text: '4343 4343',
        selection: TextSelection.collapsed(offset: 2),
      );
      final TextEditingValue v = _type(f, old, '9');
      expect(v.text, '4394 3434 3');
      expect(v.selection.baseOffset, 3);
    });
  });

  group('ExpiryInputFormatter', () {
    final ExpiryInputFormatter f = ExpiryInputFormatter();

    test('a month typed without its zero is completed', () {
      expect(_typeAll(f, '5').text, '05/');
      expect(_typeAll(f, '527').text, '05/27');
    });

    test('normal typing and paste', () {
      expect(_typeAll(f, '1227').text, '12/27');
      expect(_typeAll(f, '05').text, '05/');
      expect(_typeAll(f, '1').text, '1');
    });

    test('a 5th digit is ignored', () {
      final TextEditingValue full = _typeAll(f, '1227');
      expect(_type(f, full, '1').text, '12/27');
    });

    test('backspacing 12/27 all the way down works', () {
      TextEditingValue v = const TextEditingValue(
        text: '12/27',
        selection: TextSelection.collapsed(offset: 5),
      );
      final List<String> seen = <String>[];
      for (int i = 0; i < 5; i++) {
        v = _backspace(f, v);
        seen.add(v.text);
      }
      expect(seen, <String>['12/2', '12', '1', '', '']);
    });
  });

  group('formatPeso', () {
    test('adds thousands separators and two decimals', () {
      expect(formatPeso(0), '₱0.00');
      expect(formatPeso(5500), '₱5,500.00');
      expect(formatPeso(1234.5), '₱1,234.50');
      expect(formatPeso(12999.95), '₱12,999.95');
      expect(formatPeso(1234567.891), '₱1,234,567.89');
    });

    test('puts the minus sign before the peso sign', () {
      expect(formatPeso(-1500), '-₱1,500.00');
    });
  });
}