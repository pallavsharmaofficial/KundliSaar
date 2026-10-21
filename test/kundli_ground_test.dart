// The ground every screen sits on: the page colour, the glow, and the kundli
// drawn faintly across it. These tests pin what the design depends on: that
// it is there, that it is quiet, that it is not repainted as the page
// scrolls, and that each screen gets one of its own so a page transition
// never shows one screen through another.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/core/theme.dart';
import 'package:kundlisaar/widgets/kundli_ground.dart';

import 'support/visual.dart';

Widget app(Widget home, {Brightness brightness = Brightness.light}) =>
    themedApp(home: home, brightness: brightness);

/// The colour of one pixel of what [boundary] draws.
Future<Color> pixelAt(
  WidgetTester tester,
  Finder boundary,
  Offset logical,
) async {
  final RenderRepaintBoundary render = tester
      .renderObject<RenderRepaintBoundary>(boundary);
  late Color colour;
  await tester.runAsync(() async {
    final ui.Image image = await render.toImage();
    final ByteData data = (await image.toByteData())!;
    final int at = (logical.dy.round() * image.width + logical.dx.round()) * 4;
    colour = Color.fromARGB(
      data.getUint8(at + 3),
      data.getUint8(at),
      data.getUint8(at + 1),
      data.getUint8(at + 2),
    );
    image.dispose();
  });
  return colour;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('every screen is on the ground', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('${b.name}: a bare scaffold shows the ground, opaque', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey<String>('page'),
            child: app(const Scaffold(body: SizedBox.expand()), brightness: b),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(KundliGround), findsOneWidget);
        // The scaffold is clear: the ground is what is behind it.
        final KundliTones tones = buildTheme(
          brightness: b,
        ).extension<KundliTones>()!;
        expect(
          buildTheme(brightness: b).scaffoldBackgroundColor,
          Colors.transparent,
        );
        // Bottom right is past where the drawing fades out and away from the
        // glow: it must be the plain ground colour, fully opaque.
        final Color corner = await pixelAt(
          tester,
          find.byKey(const ValueKey<String>('page')),
          const Offset(350, 630),
        );
        expect(corner.a, 1.0);
        expect(corner.toARGB32(), tones.ground.toARGB32());
      });
    }

    testWidgets('each route has a ground of its own, home louder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('second')),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      // Halfway through the transition both screens are on stage; each
      // brings its own ground, so neither shows through the other.
      await tester.pump(const Duration(milliseconds: 150));
      final List<KundliGround> midway = tester
          .widgetList<KundliGround>(
            find.byType(KundliGround, skipOffstage: false),
          )
          .toList();
      expect(midway, hasLength(2));
      await tester.pumpAndSettle();

      final List<KundliGround> all = tester
          .widgetList<KundliGround>(
            find.byType(KundliGround, skipOffstage: false),
          )
          .toList();
      expect(all.map((KundliGround g) => g.weight), <GroundWeight>[
        GroundWeight.hero,
        GroundWeight.reading,
      ]);
      // And the scaffold of each sits inside its ground.
      expect(
        find.ancestor(
          of: find.byType(Scaffold, skipOffstage: false),
          matching: find.byType(KundliGround, skipOffstage: false),
        ),
        findsNWidgets(2),
      );
    });
  });

  group('it is quiet', () {
    test('the drawing is a faint fraction of the ink, and quieter on reading '
        'screens', () {
      for (final KundliTones t in <KundliTones>[
        KundliTones.day,
        KundliTones.night,
      ]) {
        expect(t.motifAlpha, lessThanOrEqualTo(0.12));
        expect(
          t.motifAlpha * KundliGroundPainter.readingStrength,
          lessThan(t.motifAlpha),
        );
      }
    });

    test('the lines never come within 1.25:1 of the ground', () {
      // Even where the drawing is strongest (top of the home screen) it must
      // stay a texture, not content that competes with text.
      for (final Brightness b in Brightness.values) {
        final KundliTones t = buildTheme(
          brightness: b,
        ).extension<KundliTones>()!;
        final Color line = Color.alphaBlend(
          t.motif.withValues(alpha: t.motifAlpha),
          t.ground,
        );
        final double la = line.computeLuminance();
        final double lg = t.ground.computeLuminance();
        final double ratio =
            (la > lg ? la + 0.05 : lg + 0.05) /
            (la > lg ? lg + 0.05 : la + 0.05);
        expect(ratio, lessThan(1.25), reason: '${b.name}: $ratio');
      }
    });
  });

  group('it is cheap', () {
    test('paths are kept per size, and the keep is bounded', () {
      KundliGroundPainter.clearGeometryCache();
      final KundliGroundPainter painter = KundliGroundPainter(
        ground: Palette.parchment,
        glow: Palette.parchmentGlow,
        line: Palette.maroon,
        lineAlpha: 0.1,
        weight: GroundWeight.hero,
      );
      void paint(Size size) {
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
      }

      paint(const Size(360, 800));
      paint(const Size(360, 800));
      expect(KundliGroundPainter.cachedGeometries, 1);
      paint(const Size(390, 844));
      expect(KundliGroundPainter.cachedGeometries, 2);
      for (int i = 0; i < 20; i++) {
        paint(Size(300.0 + i, 700));
      }
      expect(KundliGroundPainter.cachedGeometries, lessThanOrEqualTo(6));
      paint(Size.zero); // nothing to draw, and no failure
    });

    test('it repaints only when something it draws with changes', () {
      KundliGroundPainter make({
        Color line = Palette.maroon,
        GroundWeight weight = GroundWeight.reading,
      }) => KundliGroundPainter(
        ground: Palette.parchment,
        glow: Palette.parchmentGlow,
        line: line,
        lineAlpha: 0.1,
        weight: weight,
      );
      expect(make().shouldRepaint(make()), isFalse);
      expect(make().shouldRepaint(make(line: Palette.indigo)), isTrue);
      expect(make().shouldRepaint(make(weight: GroundWeight.hero)), isTrue);
    });

    testWidgets('scrolling, or rebuilding with the same colours, does not '
        'repaint the ground', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget page() => app(
        Scaffold(
          body: ListView(
            children: <Widget>[
              for (int i = 0; i < 80; i++)
                Card(child: ListTile(title: Text('row $i'))),
            ],
          ),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pump(const Duration(milliseconds: 400));
      final int before = KundliGroundPainter.paintCount;
      expect(before, greaterThan(0));

      for (int i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -120));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('row 0'), findsNothing, reason: 'the page did scroll');
      expect(
        KundliGroundPainter.paintCount,
        before,
        reason: 'the ground was painted again while the page scrolled',
      );

      // A rebuild builds a new painter with the same colours, which must not
      // cost a repaint either.
      await tester.pumpWidget(page());
      await tester.pump();
      expect(KundliGroundPainter.paintCount, before);
    });
  });
}
