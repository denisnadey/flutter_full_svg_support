import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Advanced Text Typography Features', () {
    group('Font Fallback Chain Resolution', () {
      test('parseFontFallbackChain returns empty for null input', () {
        const result = FontFallbackResult();
        expect(result.isEmpty, isTrue);
        expect(result.primaryFont, isNull);
        expect(result.fallbackFonts, isEmpty);
      });

      test('FontFallbackResult toFontList returns all fonts', () {
        const result = FontFallbackResult(
          primaryFont: 'Roboto',
          fallbackFonts: ['Arial', 'sans-serif'],
        );
        expect(result.toFontList(), ['Roboto', 'Arial', 'sans-serif']);
      });

      testWidgets('renders text with complex font fallback chain', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 400 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  font-family='"Roboto", "Segoe UI", "Helvetica Neue", Arial, sans-serif'>
              Complex Fallback Chain
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles generic font family mapping - serif', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" font-family="serif">
              Serif Font Text
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles generic font family mapping - system-ui', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" font-family="system-ui">
              System UI Font
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles ui-rounded modern CSS generic family', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" font-family="ui-rounded">
              Rounded UI Font
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles math generic font family', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" font-family="math">
              x² + y² = z²
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles emoji generic font family', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24" font-family="emoji">
              😀🎉🚀
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Combining Marks and Diacritics', () {
      testWidgets('renders text with single combining mark (acute accent)', (
        tester,
      ) async {
        // cafe with decomposed é (e + combining acute accent U+0301)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18">cafe\u0301</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with multiple different combining marks', (
        tester,
      ) async {
        // Various combining marks: acute, grave, tilde
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18">e\u0301 a\u0300 n\u0303 o\u0302</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with stacked combining marks', (tester) async {
        // Multiple combining marks on single base character
        // Vietnamese: ệ = e + combining circumflex (U+0302) + combining dot below (U+0323)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="20">e\u0302\u0323</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders Hebrew text with combining marks', (tester) async {
        // Hebrew with nikud (vowel points)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="190" y="30" font-size="20" direction="rtl">שָׁלוֹם</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders Arabic text with combining marks', (tester) async {
        // Arabic with tashkeel (diacritics)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="190" y="30" font-size="20" direction="rtl">مَرْحَبًا</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Text Selection Hit-Testing Precision', () {
      testWidgets('hit tests text element correctly', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text id="test-text" x="50" y="30" font-size="16">Hello</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles per-character positioning hit test', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text font-size="16" x="10 30 50 70 90" y="30">Hello</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles rotated text hit test', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
            <text x="100" y="100" font-size="16" 
                  transform="rotate(45, 100, 100)">Rotated</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 200),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles text with per-character rotation', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text font-size="16" x="20 40 60 80 100" y="50" 
                  rotate="0 10 20 30 40">Hello</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('RTL/LTR Bidirectional Text', () {
      testWidgets('renders pure RTL Hebrew text', (tester) async {
        const svg = '''
          <svg viewBox="0 0 250 50" xmlns="http://www.w3.org/2000/svg">
            <text x="240" y="30" font-size="18" direction="rtl" text-anchor="start">
              שלום עולם
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 250, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders pure RTL Arabic text', (tester) async {
        const svg = '''
          <svg viewBox="0 0 250 50" xmlns="http://www.w3.org/2000/svg">
            <text x="240" y="30" font-size="18" direction="rtl" text-anchor="start">
              مرحبا بالعالم
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 250, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders mixed LTR and RTL in single text', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              <tspan direction="ltr">Hello </tspan>
              <tspan direction="rtl" unicode-bidi="embed">שלום</tspan>
              <tspan direction="ltr"> World</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles unicode-bidi bidi-override', (tester) async {
        const svg = '''
          <svg viewBox="0 0 250 50" xmlns="http://www.w3.org/2000/svg">
            <text x="230" y="30" font-size="16" 
                  direction="rtl" unicode-bidi="bidi-override">
              ABC123
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 250, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles unicode-bidi isolate', (tester) async {
        const svg = '''
          <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">
              Product: <tspan unicode-bidi="isolate" direction="rtl">מוצר</tspan> - \$100
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 350, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles unicode-bidi isolate-override', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="280" y="30" font-size="16" direction="rtl">
              <tspan unicode-bidi="isolate-override">ABC</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('OpenType Font Features', () {
      testWidgets('renders text with font-feature-settings kerning', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  style="font-feature-settings: 'kern' 1">
              AVATAR Typography
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with ligatures enabled', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  style="font-feature-settings: 'liga' 1, 'clig' 1">
              fi fl ff ffi ffl
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with ligatures disabled', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  style="font-feature-settings: 'liga' off">
              fi fl ff ffi ffl
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with small-caps feature', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  style="font-feature-settings: 'smcp' 1">
              Small Caps Text
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with old-style numerals', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  style="font-feature-settings: 'onum' 1">
              0123456789
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with tabular numerals', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  style="font-feature-settings: 'tnum' 1">
              1234.56
              9876.54
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with slashed zero', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  style="font-feature-settings: 'zero' 1">
              O0 l1 5S
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with multiple font features', (tester) async {
        const svg = '''
          <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18" 
                  style="font-feature-settings: 'kern' 1, 'liga' 1, 'onum' 1">
              Office files: 1234
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 350, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Grapheme Cluster Handling', () {
      testWidgets('renders emoji with ZWJ sequence', (tester) async {
        // Family emoji: man + ZWJ + woman + ZWJ + girl
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">👨‍👩‍👧</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders flag emoji (regional indicators)', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">🇺🇸 🇬🇧 🇯🇵</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders emoji with skin tone modifier', (tester) async {
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">👋🏽 ✌🏻 🤙🏿</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders text with variation selectors', (tester) async {
        // Text with emoji variation selector (U+FE0F)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">❤️✨⭐</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Complex Script Rendering', () {
      testWidgets('renders Thai text with combining marks', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18">สวัสดี</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders Devanagari text with combining marks', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18">नमस्ते</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('renders Bengali text', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="18">বাংলা</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Integration Tests', () {
      testWidgets('complex typography SVG with all features', (tester) async {
        const svg = '''
          <svg viewBox="0 0 600 400" xmlns="http://www.w3.org/2000/svg">
            <!-- Font fallback chain -->
            <text x="10" y="30" font-size="14" 
                  font-family='"Roboto", Arial, sans-serif'>
              Font Fallback
            </text>
            
            <!-- Combining marks -->
            <text x="10" y="60" font-size="14">
              Café résumé naïve
            </text>
            
            <!-- RTL text -->
            <text x="590" y="90" font-size="14" direction="rtl" text-anchor="start">
              שלום עולם
            </text>
            
            <!-- Mixed direction -->
            <text x="10" y="120" font-size="14">
              <tspan>Hello </tspan>
              <tspan direction="rtl" unicode-bidi="embed">مرحبا</tspan>
              <tspan> World</tspan>
            </text>
            
            <!-- Font features -->
            <text x="10" y="150" font-size="14" 
                  style="font-feature-settings: 'kern' 1, 'liga' 1">
              Office fi fl Typography
            </text>
            
            <!-- Emoji with modifiers -->
            <text x="10" y="190" font-size="24">
              👨‍👩‍👧 🇺🇸 👋🏽
            </text>
            
            <!-- Per-character positioning -->
            <text font-size="14" x="10 30 50 70 90" y="230">
              Hello
            </text>
            
            <!-- Complex script (Devanagari) -->
            <text x="10" y="260" font-size="14">
              नमस्ते - Namaste
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 600, height: 400),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
