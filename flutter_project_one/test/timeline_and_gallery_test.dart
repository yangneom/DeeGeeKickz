// Put this file at:  test/timeline_and_gallery_test.dart
// Run with:          flutter test test/timeline_and_gallery_test.dart
//
// "flutter_project_one" is the package name assumed from your project folder.
// If pubspec.yaml says something else, change the two imports below.
//
// Written but NOT run (no Flutter was available when these were written).
// They use no network and no real orders. In tests, Image.network always
// fails to load, which is fine here: the gallery's own error placeholder
// handles it, and these tests check layout and behaviour, not pictures.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_one/widgets/customer/orders/order_tracking_timeline.dart';
import 'package:flutter_project_one/widgets/customer/product_detail/product_image_gallery.dart';

const List<String> _steps = <String>[
  'Pending',
  'Confirmed',
  'Preparing',
  'Shipped',
  'Delivered',
];

Widget _timeline({
  required double width,
  int current = 0,
  List<String?> timestamps = const <String?>[null, null, null, null, null],
  List<String?> notes = const <String?>[],
  List<String> steps = _steps,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: OrderTrackingTimeline(
            steps: steps,
            currentStep: current,
            timestamps: timestamps,
            notes: notes,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('OrderTrackingTimeline', () {
    testWidgets('narrow phone (300px): vertical layout, no overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(_timeline(width: 300, current: 1));
      expect(tester.takeException(), isNull);
      for (final String s in _steps) {
        expect(find.text(s.toUpperCase()), findsOneWidget);
      }
      // The vertical layout names the current step in words, not only by colour.
      expect(find.text('CURRENT'), findsOneWidget);
    });

    testWidgets('wide (800px): horizontal layout, no overflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(_timeline(width: 800, current: 2));
      expect(tester.takeException(), isNull);
      for (final String s in _steps) {
        expect(find.text(s.toUpperCase()), findsOneWidget);
      }
      expect(find.text('CURRENT'), findsNothing); // ring + bold instead
    });

    testWidgets('a long label wraps instead of overflowing, even at the narrowest horizontal width',
        (WidgetTester tester) async {
      await tester.pumpWidget(_timeline(
        width: 560,
        current: 0,
        steps: const <String>[
          'Awaiting Payment',
          'Confirmed',
          'Preparing',
          'Shipped',
          'Delivered',
        ],
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('AWAITING PAYMENT'), findsOneWidget);
    });

    testWidgets('prints only the dates it is given and never makes one up',
        (WidgetTester tester) async {
      await tester.pumpWidget(_timeline(
        width: 320,
        current: 0,
        timestamps: const <String?>['10/19/2026 3:45 pm', null, null, null, null],
      ));
      expect(find.text('10/19/2026 3:45 pm'), findsOneWidget);
      expect(find.text('Est. soon'), findsNothing); // the old made-up estimate
    });

    testWidgets('a delivered order shows every step finished (5 ticks), no "current"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_timeline(width: 320, current: 4));
      expect(find.byIcon(Icons.check), findsNWidgets(5));
      expect(find.text('CURRENT'), findsNothing);
    });

    testWidgets('a pending order has no ticks yet and marks the first step current',
        (WidgetTester tester) async {
      await tester.pumpWidget(_timeline(width: 320, current: 0));
      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.text('CURRENT'), findsOneWidget);
    });

    testWidgets('a note shows under its step',
        (WidgetTester tester) async {
      await tester.pumpWidget(_timeline(
        width: 320,
        current: 0,
        notes: const <String?>['Waiting for the store to confirm your order.', null, null, null, null],
      ));
      expect(find.text('Waiting for the store to confirm your order.'), findsOneWidget);
    });
  });

  group('ProductImageGallery', () {
    Widget gallery(List<String> urls) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductImageGallery(imageUrls: urls),
            ),
          ),
        );

    testWidgets('no images: a clear placeholder, no crash',
        (WidgetTester tester) async {
      await tester.pumpWidget(gallery(const <String>[]));
      expect(tester.takeException(), isNull);
      expect(find.text('No image available'), findsOneWidget);
    });

    testWidgets('phone: dots can be tapped and say which image is showing',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(gallery(const <String>['a', 'b', 'c']));
      expect(find.bySemanticsLabel('Image 1 of 3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Show image 2'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Image 2 of 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('changing colour (a different list) returns to the first image',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(gallery(const <String>['a', 'b', 'c']));
      await tester.tap(find.bySemanticsLabel('Show image 3'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Image 3 of 3'), findsOneWidget);

      // The new colour has only two images.
      await tester.pumpWidget(gallery(const <String>['x', 'y']));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Image 1 of 2'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('desktop: thumbnail strip with several images, none with one',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(gallery(const <String>['a', 'b', 'c']));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Show image 2 of 3'), findsOneWidget);

      await tester.pumpWidget(gallery(const <String>['only']));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp('Show image')), findsNothing);
      handle.dispose();
    });
  });
}