import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('Font Registration Lifecycle', () {
    testWidgets('Widget with SVG containing @font-face auto-registers fonts',
        (WidgetTester tester) async {
      // SVG with embedded @font-face rule (minimal valid base64 data)
      const svgWithFont = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'TestFont';
      src: url(data:font/ttf;base64,AAEAAAALAI) format('truetype');
    }
  </style>
  <text x="10" y="50" font-family="TestFont">Hello</text>
</svg>
''';

      // Track trace events for verification
      final traceEvents = <SvgTraceEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSvgPicture.string(
            svgWithFont,
            width: 100,
            height: 100,
            autoPlay: false,
            onTrace: (event) => traceEvents.add(event),
          ),
        ),
      );

      // Wait for async font registration to complete
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify that font registration was scheduled
      final fontScheduledEvent = traceEvents.firstWhere(
        (e) => e.category == 'font' && e.message == 'Font registration scheduled',
        orElse: () => throw TestFailure('Font registration was not scheduled'),
      );
      expect(fontScheduledEvent.data['count'], equals(1));

      // Verify that font registration completed (or failed gracefully)
      final fontCompletedEvent = traceEvents.where(
        (e) =>
            e.category == 'font' &&
            (e.message == 'Font registration completed' ||
                e.message == 'Font registration completed with errors' ||
                e.message == 'Font registration failed'),
      );
      expect(
        fontCompletedEvent.isNotEmpty,
        isTrue,
        reason: 'Font registration should complete or fail gracefully',
      );
    });

    testWidgets('Widget with SVG without @font-face does not try to register',
        (WidgetTester tester) async {
      const svgWithoutFont = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect x="10" y="10" width="80" height="80" fill="blue"/>
</svg>
''';

      final traceEvents = <SvgTraceEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSvgPicture.string(
            svgWithoutFont,
            width: 100,
            height: 100,
            autoPlay: false,
            onTrace: (event) => traceEvents.add(event),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify no font registration was attempted
      final fontEvents = traceEvents.where((e) => e.category == 'font');
      expect(
        fontEvents.isEmpty,
        isTrue,
        reason:
            'No font events should occur for SVG without @font-face',
      );
    });

    testWidgets('SVG string change re-triggers font registration',
        (WidgetTester tester) async {
      const svgWithFont1 = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'Font1';
      src: url(data:font/ttf;base64,AAEAAAALAI) format('truetype');
    }
  </style>
  <text x="10" y="50" font-family="Font1">First</text>
</svg>
''';

      const svgWithFont2 = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'Font2';
      src: url(data:font/ttf;base64,AAEAAAALAI) format('truetype');
    }
  </style>
  <text x="10" y="50" font-family="Font2">Second</text>
</svg>
''';

      final traceEvents = <SvgTraceEvent>[];
      var svgString = svgWithFont1;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return AnimatedSvgPicture.string(
                svgString,
                key: ValueKey(svgString),
                width: 100,
                height: 100,
                autoPlay: false,
                onTrace: (event) => traceEvents.add(event),
              );
            },
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Count initial font scheduled events
      final initialFontScheduledCount = traceEvents
          .where(
            (e) =>
                e.category == 'font' &&
                e.message == 'Font registration scheduled',
          )
          .length;
      expect(initialFontScheduledCount, equals(1));

      // Change the SVG
      svgString = svgWithFont2;
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSvgPicture.string(
            svgString,
            key: ValueKey(svgString),
            width: 100,
            height: 100,
            autoPlay: false,
            onTrace: (event) => traceEvents.add(event),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify font registration was scheduled again for new SVG
      final totalFontScheduledCount = traceEvents
          .where(
            (e) =>
                e.category == 'font' &&
                e.message == 'Font registration scheduled',
          )
          .length;
      expect(
        totalFontScheduledCount,
        equals(2),
        reason: 'Font registration should be triggered for both SVG changes',
      );
    });

    test('SvgDocument.cssFontFaceRules returns parsed rules', () {
      const svgWithFont = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'CustomFont';
      font-weight: 400;
      src: url(data:font/ttf;base64,AAEAAAALAI) format('truetype');
    }
  </style>
  <text>Test</text>
</svg>
''';

      final document = SvgParser.parse(svgWithFont);
      final fontFaceRules = document.cssFontFaceRules;

      expect(fontFaceRules, isNotNull);
      expect(fontFaceRules, hasLength(1));
      expect(fontFaceRules!.first.fontFamily, equals('CustomFont'));
      expect(fontFaceRules.first.fontWeight, equals('400'));
    });

    test('SvgDocument.registerEmbeddedFonts returns Future<bool>', () async {
      const svgWithFont = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'TestRegister';
      src: url(data:font/ttf;base64,AAEAAAALAI) format('truetype');
    }
  </style>
  <text>Test</text>
</svg>
''';

      final document = SvgParser.parse(svgWithFont);

      // registerEmbeddedFonts should return a Future<bool>
      final result = document.registerEmbeddedFonts();
      expect(result, isA<Future<bool>>());

      // The result may be true or false depending on font data validity
      final success = await result;
      expect(success, isA<bool>());
    });

    testWidgets('Guard against unmounted callback', (WidgetTester tester) async {
      const svgWithFont = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'UnmountTest';
      src: url(data:font/ttf;base64,AAEAAAALAI) format('truetype');
    }
  </style>
  <text x="10" y="50" font-family="UnmountTest">Test</text>
</svg>
''';

      final traceEvents = <SvgTraceEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSvgPicture.string(
            svgWithFont,
            width: 100,
            height: 100,
            autoPlay: false,
            onTrace: (event) => traceEvents.add(event),
          ),
        ),
      );

      // Immediately dispose widget before font registration completes
      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );

      // Wait for any pending async operations
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // No error should occur - the callback should be guarded by mounted check
      // The test passes if no exceptions are thrown
    });

    test('SvgDocument without @font-face returns empty or null', () {
      const svgWithoutFont = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect x="10" y="10" width="80" height="80" fill="blue"/>
</svg>
''';

      final document = SvgParser.parse(svgWithoutFont);
      final fontFaceRules = document.cssFontFaceRules;

      // Should be null or empty
      expect(
        fontFaceRules == null || fontFaceRules.isEmpty,
        isTrue,
        reason: 'SVG without @font-face should have no font rules',
      );
    });

    testWidgets('Multiple @font-face rules are all registered',
        (WidgetTester tester) async {
      const svgWithMultipleFonts = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <style>
    @font-face {
      font-family: 'FontA';
      src: url(data:font/ttf;base64,AAEAAAALAI) format('truetype');
    }
    @font-face {
      font-family: 'FontB';
      src: url(data:font/ttf;base64,AAEAAAALAI) format('truetype');
    }
  </style>
  <text x="10" y="30" font-family="FontA">TextA</text>
  <text x="10" y="60" font-family="FontB">TextB</text>
</svg>
''';

      final traceEvents = <SvgTraceEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedSvgPicture.string(
            svgWithMultipleFonts,
            width: 100,
            height: 100,
            autoPlay: false,
            onTrace: (event) => traceEvents.add(event),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Verify that all font rules were counted
      final fontScheduledEvent = traceEvents.firstWhere(
        (e) => e.category == 'font' && e.message == 'Font registration scheduled',
        orElse: () => throw TestFailure('Font registration was not scheduled'),
      );
      expect(fontScheduledEvent.data['count'], equals(2));
    });
  });
}
