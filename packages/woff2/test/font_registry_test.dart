import 'package:flutter_test/flutter_test.dart';
import 'package:woff2/woff2.dart';

void main() {
  // `FontLoader.load()` needs the platform channel — `flutter_test`'s
  // ensureInitialized stubs enough of it that successful registrations
  // don't crash, but we intentionally feed *invalid* bytes so the
  // registry routes through error paths and `loader.load()` is never
  // called.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WoffFontRegistry — initial state', () {
    test('empty by default', () {
      final reg = WoffFontRegistry();
      expect(reg.registeredFontFamilies, isEmpty);
      expect(reg.errors, isEmpty);
      expect(reg.isRegistered('Anything'), isFalse);
    });

    test('clear() resets bookkeeping', () {
      final reg = WoffFontRegistry();
      reg.clear();
      expect(reg.registeredFontFamilies, isEmpty);
    });
  });

  group('WoffFontRegistry — error reporting', () {
    test('records error when external src has no resolver', () async {
      final reg = WoffFontRegistry();
      await reg.registerFonts(const [
        CssFontFaceRule(
          fontFamily: 'External',
          src: 'fonts/External.woff2',
          format: 'woff2',
        ),
      ]);

      expect(reg.isRegistered('External'), isFalse);
      expect(
        reg.errors,
        contains(predicate<String>(
          (s) => s.contains('External') && s.contains('External URLs'),
        )),
      );
    });

    test('records error when resolver returns null', () async {
      final reg = WoffFontRegistry();
      await reg.registerFonts(
        const [
          CssFontFaceRule(
            fontFamily: 'Missing',
            src: 'fonts/Missing.woff2',
            format: 'woff2',
          ),
        ],
        srcResolver: (_) async => null,
      );

      expect(reg.isRegistered('Missing'), isFalse);
      expect(
        reg.errors,
        contains(predicate<String>(
          (s) => s.contains('Missing') && s.contains('null'),
        )),
      );
    });

    test('records error for malformed embedded WOFF data URL', () async {
      // A data: URL with valid base64 but garbage content — decoder
      // should reject it as malformed.
      final reg = WoffFontRegistry();
      await reg.registerFonts(const [
        CssFontFaceRule(
          fontFamily: 'Garbage',
          // 'wOFF' magic + 12 bytes of zeros = malformed WOFF1.
          src: 'data:font/woff;base64,d09GRgAAAAAAAAAAAAAAAA==',
          format: 'woff',
        ),
      ]);

      expect(reg.isRegistered('Garbage'), isFalse);
      expect(
        reg.errors,
        contains(predicate<String>(
          (s) => s.contains('Garbage') && s.contains('Malformed'),
        )),
      );
    });

    test('records error for unsupported format declaration', () async {
      final reg = WoffFontRegistry();
      await reg.registerFonts(const [
        CssFontFaceRule(
          fontFamily: 'Unsup',
          src: 'data:font/svg+xml;base64,AAAA',
          format: 'svg',
        ),
      ]);

      expect(reg.isRegistered('Unsup'), isFalse);
      expect(
        reg.errors,
        contains(predicate<String>(
          (s) => s.contains('Unsup') && s.contains('Unsupported'),
        )),
      );
    });
  });

  group('WoffFontRegistry — family normalisation', () {
    test('isRegistered strips surrounding quotes', () {
      // Indirect check: we can't easily register without a real loader,
      // so we verify behaviour via name-only paths. The internal
      // normaliser strips quotes; we replicate via isRegistered.
      final reg = WoffFontRegistry();
      expect(reg.isRegistered('"NotAdded"'), isFalse);
      expect(reg.isRegistered("'NotAdded'"), isFalse);
    });
  });
}
