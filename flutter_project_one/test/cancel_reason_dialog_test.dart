// Put this file at:  test/cancel_reason_dialog_test.dart
// Run with:          flutter test test/cancel_reason_dialog_test.dart
//
// "flutter_project_one" is the package name assumed from your project folder.
// If pubspec.yaml says something else, change the two imports below.
//
// These tests were written but NOT run (no Flutter was available when they were
// written). They check the dialog's behaviour with fake callbacks: no network,
// no database, no real orders.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_one/widgets/common/dialog/cancel_reason_dialog.dart';
import 'package:flutter_project_one/widgets/customer/orders/order_status_style.dart';

Widget _host({
  required Future<void> Function(String reason) onConfirm,
  CancelDialogStyle style = CancelDialogStyle.customer,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showCancelReasonDialog(
            context: context,
            style: style,
            title: 'Cancel Order',
            subtitle: 'Why are you cancelling?',
            confirmLabel: 'Cancel Order',
            dismissLabel: style == CancelDialogStyle.customer ? 'Keep Order' : null,
            confirmColor: const Color(0xFFBA1A1A),
            reasons: const ['Changed my mind', 'Ordered by mistake'],
            onConfirm: onConfirm,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

// The customer title and the confirm button both read "CANCEL ORDER"; the
// button comes later in the tree.
Finder get _confirmButton => find.text('CANCEL ORDER').last;

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('customer style', () {
    testWidgets('confirming with no reason explains why and sends nothing',
        (WidgetTester tester) async {
      int calls = 0;
      await tester.pumpWidget(_host(onConfirm: (String r) async => calls++));
      await _open(tester);

      await tester.tap(_confirmButton);
      await tester.pump();

      expect(find.text('Please select a reason.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a chosen reason is sent once and the dialog closes',
        (WidgetTester tester) async {
      final List<String> sent = <String>[];
      await tester.pumpWidget(_host(onConfirm: (String r) async => sent.add(r)));
      await _open(tester);

      await tester.tap(find.text('Ordered by mistake'));
      await tester.pump();
      await tester.tap(_confirmButton);
      await tester.pumpAndSettle();

      expect(sent, <String>['Ordered by mistake']);
      expect(find.text('Why are you cancelling?'), findsNothing);
    });

    testWidgets('"Others" needs text, and the text is trimmed',
        (WidgetTester tester) async {
      final List<String> sent = <String>[];
      await tester.pumpWidget(_host(onConfirm: (String r) async => sent.add(r)));
      await _open(tester);

      await tester.tap(find.text('Others'));
      await tester.pump();
      await tester.tap(_confirmButton);
      await tester.pump();
      expect(find.text('Please tell us the reason.'), findsOneWidget);
      expect(sent, isEmpty);

      await tester.enterText(find.byType(TextField), '   too expensive   ');
      await tester.pump();
      await tester.tap(_confirmButton);
      await tester.pumpAndSettle();
      expect(sent, <String>['too expensive']);
    });

    testWidgets('a second tap while the request runs sends nothing more',
        (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      int calls = 0;
      await tester.pumpWidget(_host(onConfirm: (String r) {
        calls++;
        return gate.future;
      }));
      await _open(tester);

      await tester.tap(find.text('Changed my mind'));
      await tester.pump();
      await tester.tap(_confirmButton);
      await tester.pump();
      await tester.tap(find.text('Processing...'));
      await tester.pump();

      expect(calls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('tapping outside does not close the dialog while it is working',
        (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      await tester.pumpWidget(_host(onConfirm: (String r) => gate.future));
      await _open(tester);

      await tester.tap(find.text('Changed my mind'));
      await tester.pump();
      await tester.tap(_confirmButton);
      await tester.pump();

      await tester.tapAt(const Offset(2, 2)); // the dark area outside the dialog
      await tester.pumpAndSettle();
      expect(find.text('Why are you cancelling?'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Why are you cancelling?'), findsNothing);
    });

    testWidgets('"Keep Order" closes without cancelling',
        (WidgetTester tester) async {
      int calls = 0;
      await tester.pumpWidget(_host(onConfirm: (String r) async => calls++));
      await _open(tester);

      await tester.tap(find.text('KEEP ORDER'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.text('Why are you cancelling?'), findsNothing);
    });

    testWidgets('an order that was already processed shows a clear message',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(onConfirm: (String r) async {
        throw Exception('P1005 This order is no longer Pending');
      }));
      await _open(tester);

      await tester.tap(find.text('Changed my mind'));
      await tester.pump();
      await tester.tap(_confirmButton);
      await tester.pumpAndSettle();

      expect(
        find.text('This order can no longer be cancelled because it has '
            'already been processed.'),
        findsOneWidget,
      );
      // Still open, and the customer can try again or go back.
      expect(find.text('Why are you cancelling?'), findsOneWidget);
    });

    testWidgets('a caller that closes the dialog itself does not close the page below',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (BuildContext homeContext) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(homeContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Builder(
                      builder: (BuildContext pageContext) => TextButton(
                        onPressed: () => showCancelReasonDialog(
                          context: pageContext,
                          style: CancelDialogStyle.customer,
                          title: 'Cancel Order',
                          subtitle: 'Why are you cancelling?',
                          confirmLabel: 'Cancel Order',
                          confirmColor: const Color(0xFFBA1A1A),
                          reasons: const ['Changed my mind'],
                          // This is what the old tile did: it popped inside
                          // onConfirm AND the dialog popped itself.
                          onConfirm: (String r) async {
                            Navigator.of(pageContext).pop();
                          },
                        ),
                        child: const Text('open dialog'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('go to page'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('go to page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Changed my mind'));
      await tester.pump();
      await tester.tap(_confirmButton);
      await tester.pumpAndSettle();

      // The dialog is gone, but the page it was opened from is still there.
      expect(find.text('Why are you cancelling?'), findsNothing);
      expect(find.text('open dialog'), findsOneWidget);
    });
  });

  group('admin style (must stay as it was)', () {
    testWidgets('keeps its own wording and has no second button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _host(onConfirm: (String r) async {}, style: CancelDialogStyle.admin));
      await _open(tester);

      expect(find.text('Cancel Order'), findsNWidgets(2)); // title + button, not uppercased
      expect(find.text('KEEP ORDER'), findsNothing);
      expect(find.text('Others'), findsOneWidget);
    });

    testWidgets('still asks for a reason with its original message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _host(onConfirm: (String r) async {}, style: CancelDialogStyle.admin));
      await _open(tester);

      await tester.tap(find.text('Cancel Order').last);
      await tester.pump();
      expect(find.text('Please select or specify a reason.'), findsOneWidget);
    });
  });

  group('orderStatusColor', () {
    test('uses one colour per status, whatever the letter case', () {
      expect(orderStatusColor('Pending'), const Color(0xFF92400E));
      expect(orderStatusColor('CONFIRMED'), const Color(0xFF1D4ED8));
      expect(orderStatusColor('shipped'), const Color(0xFF1A5276));
      expect(orderStatusColor('Delivered'), orderStatusColor('completed'));
      expect(orderStatusColor('Cancelled'), const Color(0xFF991B1B));
    });

    test('an unknown status gets the neutral grey, not black', () {
      expect(orderStatusColor('something new'), const Color(0xFF656464));
    });
  });
}