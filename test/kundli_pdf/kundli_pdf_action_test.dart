import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/data/places_repository.dart';
import 'package:kundlisaar/engine/astro/ayanamsa.dart';
import 'package:kundlisaar/engine/jyotish/chart.dart';
import 'package:kundlisaar/kundli_pdf/delivery/kundli_pdf_service.dart';
import 'package:kundlisaar/kundli_pdf/kundli_pdf_password.dart';
import 'package:kundlisaar/models/saved_profile.dart';
import 'package:kundlisaar/screens/chart_screen.dart';
import 'package:kundlisaar/screens/kundli_pdf_action.dart';

import '../screens_test.dart' as screens;

/// The password gate in the app: the prompt comes first, a wrong password makes
/// nothing, the right one shows the progress dialog and then hands the file
/// over.
void main() {
  final SavedProfile profile = SavedProfile(
    id: 'p1',
    name: 'पल्लव शर्मा',
    localDateTime: DateTime(1996, 6, 13, 8, 30),
    offsetMinutes: 330,
    place: const Place(
      name: 'Delhi',
      admin: 'Delhi',
      country: 'IN',
      latitude: 28.6139,
      longitude: 77.2090,
      timeZoneId: 'Asia/Kolkata',
      population: 10927986,
    ),
  );

  int made = 0;
  final List<String> delivered = <String>[];
  late Completer<void> pending;

  Future<KundliPdfFile> maker({
    required BirthData birth,
    required Ayanamsa ayanamsa,
    required DateTime now,
    void Function(String stage)? onStage,
  }) async {
    made++;
    onStage?.call('कुंडली बन रही है');
    await pending.future;
    return KundliPdfFile(
      bytes: Uint8List.fromList(<int>[37, 80, 68, 70]),
      pageCount: 3,
      fileName: 'KundliSaar_test.pdf',
    );
  }

  Future<void> deliver({
    required Uint8List bytes,
    required String fileName,
    String? subject,
    Rect? origin,
  }) async {
    delivered.add(fileName);
  }

  Future<void> pumpHost(WidgetTester tester) async {
    // Made here, inside the test's own zone, so that what waits on it resumes
    // when the test pumps.
    pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => downloadKundliPdf(
                context,
                profile: profile,
                ayanamsa: Ayanamsa.lahiri,
                hindi: true,
                maker: maker,
                deliver: deliver,
              ),
              child: const Text('डाउनलोड'),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    made = 0;
    delivered.clear();
  });

  testWidgets('the password is asked for before anything is made', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('डाउनलोड'));
    await tester.pumpAndSettle();
    expect(find.text('पासवर्ड डालें'), findsOneWidget);
    expect(made, 0);
    await tester.tap(find.text('रद्द करें'));
    await tester.pumpAndSettle();
    expect(find.text('पासवर्ड डालें'), findsNothing);
    expect(made, 0);
    expect(delivered, isEmpty);
  });

  testWidgets('a wrong password is refused and nothing is made', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('डाउनलोड'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '13061997');
    await tester.tap(find.text('आगे बढ़ें'));
    await tester.pump();
    expect(find.text('पासवर्ड ग़लत है'), findsOneWidget);
    expect(
      find.text('पासवर्ड डालें'),
      findsOneWidget,
      reason: 'the prompt stays',
    );
    expect(made, 0);
    // Editing clears the complaint.
    await tester.enterText(find.byType(TextField), '1306199');
    await tester.pump();
    expect(find.text('पासवर्ड ग़लत है'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('आगे बढ़ें'));
    await tester.pump();
    expect(find.text('पासवर्ड ग़लत है'), findsOneWidget);
    expect(made, 0);
  });

  testWidgets('the password is hidden as it is typed', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('डाउनलोड'));
    await tester.pumpAndSettle();
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
  });

  testWidgets('the right password shows progress, then hands the file over', (
    WidgetTester tester,
  ) async {
    await pumpHost(tester);
    await tester.tap(find.text('डाउनलोड'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), kundliPdfPassword);
    await tester.tap(find.text('आगे बढ़ें'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('आपकी जन्म पत्रिका बन रही है'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(made, 1);
    expect(delivered, isEmpty);

    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('आपकी जन्म पत्रिका बन रही है'), findsNothing);
    expect(delivered, <String>['KundliSaar_test.pdf']);
  });

  test('the file name is safe and readable', () {
    final DateTime now = DateTime(2026, 10, 21);
    expect(
      kundliPdfFileName('पल्लव शर्मा', now),
      'KundliSaar_पल्लव_शर्मा_20261021.pdf',
    );
    expect(
      kundliPdfFileName('  a/b:c*d  ', now),
      'KundliSaar_abcd_20261021.pdf',
    );
    expect(kundliPdfFileName('', now), 'KundliSaar_kundli_20261021.pdf');
  });

  group('on the chart screen', () {
    testWidgets('the action is in the app bar and the panel has its button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await screens.wrap(const ChartScreen(profileId: 'test')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey<String>('kundli-pdf-action')),
        findsOneWidget,
      );
      // The panel is down the page; the list builds it only when scrolled to.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey<String>('kundli-pdf-button')),
        300,
        scrollable: find.byType(Scrollable).at(1),
      );
      expect(
        find.byKey(const ValueKey<String>('kundli-pdf-button')),
        findsOneWidget,
      );
      // Tapping it asks for the password first.
      await tester.tap(find.byKey(const ValueKey<String>('kundli-pdf-action')));
      await tester.pumpAndSettle();
      expect(find.text('पासवर्ड डालें'), findsOneWidget);
      await tester.tap(find.text('रद्द करें'));
      await tester.pumpAndSettle();
      expect(find.text('पासवर्ड डालें'), findsNothing);
    });
  });
}
