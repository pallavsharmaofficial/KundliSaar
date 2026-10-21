import 'package:flutter_test/flutter_test.dart';
import 'package:kundlisaar/palm/camera_source.dart';
import 'package:kundlisaar/palm/capture_copy.dart';
import 'package:kundlisaar/palm/palm_scan.dart';
import 'package:kundlisaar/palm/web_model.dart';

void main() {
  group('the browser camera\'s decisions', () {
    test('mirror a webcam, which reports nothing, and a front camera', () {
      expect(previewMirroredFor(null), isTrue);
      expect(previewMirroredFor(''), isTrue);
      expect(previewMirroredFor('user'), isTrue);
    });

    test('and show a camera that faces away from the person as it is', () {
      expect(previewMirroredFor('environment'), isFalse);
    });

    test(
      'call a refusal a refusal, and everything else a camera that is not there',
      () {
        for (final String name in <String>[
          'NotAllowedError',
          'PermissionDeniedError',
          'SecurityError',
        ]) {
          expect(
            cameraProblemFromBrowserError(name),
            CameraProblem.denied,
            reason: name,
          );
        }
        for (final String? name in <String?>[
          'NotFoundError',
          'NotReadableError',
          'OverconstrainedError',
          'AbortError',
          'TypeError',
          null,
        ]) {
          expect(
            cameraProblemFromBrowserError(name),
            CameraProblem.unavailable,
            reason: '$name',
          );
        }
      },
    );

    test(
      'draw a frame at the video\'s own size, or shrunk to keep the long side to 1280',
      () {
        expect(captureSize(1280, 720), (1280, 720));
        expect(captureSize(720, 1280), (720, 1280));
        expect(captureSize(640, 480), (640, 480));
        expect(captureSize(1920, 1080), (1280, 720));
        expect(captureSize(1080, 1920), (720, 1280));
        expect(captureSize(3840, 2160), (1280, 720));
      },
    );
  });

  group('where the browser looks for the runtime', () {
    test(
      'is the litert folder next to the app, under a sub-path as GitHub Pages serves it',
      () {
        expect(
          litertDirectory(
            'https://pallavsharmaofficial.github.io/KundliSaar/app/',
          ).toString(),
          'https://pallavsharmaofficial.github.io/KundliSaar/app/litert/',
        );
      },
    );

    test('and at the root of a site, or on a local server', () {
      expect(
        litertDirectory('https://example.org/').toString(),
        'https://example.org/litert/',
      );
      expect(
        litertDirectory('http://localhost:8080/').toString(),
        'http://localhost:8080/litert/',
      );
    });

    test('always on the page\'s own origin, whatever the base looks like', () {
      for (final String base in <String>[
        'https://pallavsharmaofficial.github.io/KundliSaar/app/',
        'https://example.org/',
        'http://127.0.0.1:5000/some/where/',
      ]) {
        final Uri page = Uri.parse(base);
        final Uri dir = litertDirectory(base);
        expect(dir.scheme, page.scheme);
        expect(dir.host, page.host);
        expect(dir.port, page.port);
        expect(dir.path, endsWith('/litert/'));
      }
    });
  });

  group('what the camera screen says', () {
    const CaptureCopy web = CaptureCopy(web: true);
    const CaptureCopy phone = CaptureCopy(web: false);

    List<(String, Say)> all(CaptureCopy c) => <(String, Say)>[
      ('privacyShort', c.privacyShort),
      ('privacyLong', c.privacyLong),
      ('holdStep', c.holdStep),
      ('cameraAsk', c.cameraAsk),
      ('startingCamera', c.startingCamera),
      ('loadingDetector', c.loadingDetector),
      ('deniedTitle', c.deniedTitle),
      ('deniedBody', c.deniedBody),
      ('unavailableBody', c.unavailableBody),
      ('modelsTitle', c.modelsTitle),
      ('modelsBody', c.modelsBody),
      if (c.downloadNote != null) ('downloadNote', c.downloadNote!),
    ];

    test(
      'is in both languages for everything, on the web and on the phone',
      () {
        for (final CaptureCopy c in <CaptureCopy>[web, phone]) {
          for (final (String name, Say say) in all(c)) {
            expect(say.english.trim(), isNotEmpty, reason: name);
            expect(say.hindi.trim(), isNotEmpty, reason: name);
            expect(say.hindi, isNot(say.english), reason: name);
            // Hindi in Devanagari, not English left in by mistake.
            expect(RegExp('[ऀ-ॿ]').hasMatch(say.hindi), isTrue, reason: name);
          }
        }
      },
    );

    test(
      'promises, in a browser, that the picture stays in the browser and is not uploaded',
      () {
        for (final bool hindi in <bool>[false, true]) {
          expect(
            web.privacyShort.of(hindi),
            isNot(contains(hindi ? 'फ़ोन' : 'phone')),
          );
          expect(
            web.privacyLong.of(hindi),
            isNot(contains(hindi ? 'फ़ोन' : 'phone')),
          );
        }
        expect(web.privacyShort.english, contains('browser'));
        expect(web.privacyShort.english, contains('Nothing is uploaded'));
        expect(web.privacyLong.english, contains('never uploaded'));
        expect(web.privacyLong.english, contains('this website itself'));
        expect(web.privacyShort.hindi, contains('ब्राउज़र'));
        expect(web.privacyLong.hindi, contains('इसी वेबसाइट'));
      },
    );

    test(
      'says before anything is asked that the browser will ask, and what is downloaded',
      () {
        expect(
          web.cameraAsk.english,
          contains('browser will ask your permission'),
        );
        expect(web.downloadNote, isNotNull);
        expect(web.downloadNote!.english, contains('17 MB'));
        expect(web.downloadNote!.english, contains('from this site'));
        expect(phone.downloadNote, isNull);
      },
    );

    test('sends nobody to a phone\'s settings from a web page', () {
      expect(web.offersSettings, isFalse);
      expect(phone.offersSettings, isTrue);
      expect(web.deniedBody.english, contains('Allow'));
    });

    test(
      'lets a failed download be tried again, which a phone that cannot run the models cannot',
      () {
        expect(web.modelsCanRetry, isTrue);
        expect(phone.modelsCanRetry, isFalse);
      },
    );

    test('says on the phone exactly what the phone app has always said', () {
      expect(
        phone.privacyShort.english,
        'Your photograph stays on this phone. Nothing is uploaded.',
      );
      expect(phone.deniedTitle.english, 'The camera is off for this app');
      expect(
        phone.modelsTitle.english,
        'Hand detection could not start on this phone',
      );
    });
  });
}
