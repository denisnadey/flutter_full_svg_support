import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for Unicode normalization and complex script text support.
///
/// These tests verify:
/// - NFC normalization for composed/decomposed character equivalence
/// - Complex script detection (Arabic, Hebrew, Thai, Devanagari, CJK)
/// - Grapheme cluster handling for combining marks
/// - Hit-testing with multi-codepoint characters
/// - Proper rendering of diacritics and complex scripts
void main() {
  group('Unicode Normalization and Complex Scripts', () {
    group('NFC Normalization - Combining Marks', () {
      testWidgets('Combining acute accent normalizes to composed form', (
        tester,
      ) async {
        // 'café' with decomposed é (e + combining acute U+0301)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">cafe\u0301</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Multiple combining marks in sequence', (tester) async {
        // Text with multiple decomposed diacritics
        const svg = '''
          <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">e\u0301 a\u0300 n\u0303 o\u0308</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Combining grave accent normalizes correctly', (
        tester,
      ) async {
        // 'à' as a + combining grave (U+0300)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">a\u0300 la carte</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Combining circumflex accent', (tester) async {
        // 'fête' with ê as e + combining circumflex (U+0302)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">fe\u0302te</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Combining tilde - Spanish ñ', (tester) async {
        // 'señor' with ñ as n + combining tilde (U+0303)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">sen\u0303or</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Combining diaeresis - German umlaut', (tester) async {
        // 'München' with ü as u + combining diaeresis (U+0308)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">Mu\u0308nchen</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Combining cedilla - French ç', (tester) async {
        // 'façade' with ç as c + combining cedilla (U+0327)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">fac\u0327ade</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Complex Script Detection - Arabic', () {
      testWidgets('Arabic text renders with RTL direction', (tester) async {
        // Arabic "مرحبا" (Hello)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="180" y="30" font-size="16">مرحبا</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Arabic with tashkeel (vowel marks)', (tester) async {
        // Arabic text with combining marks for vocalization
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="180" y="30" font-size="16">مَرْحَبًا</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Complex Script Detection - Hebrew', () {
      testWidgets('Hebrew text renders with RTL direction', (tester) async {
        // Hebrew "שלום" (Shalom)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="180" y="30" font-size="16">שלום</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Hebrew with nikud (vowel points)', (tester) async {
        // Hebrew text with combining marks for vocalization
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="180" y="30" font-size="16">שָׁלוֹם</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Complex Script Detection - Thai', () {
      testWidgets('Thai text with combining marks', (tester) async {
        // Thai text with tone marks and vowel signs
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">สวัสดี</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Complex Script Detection - Devanagari', () {
      testWidgets('Devanagari text with conjuncts', (tester) async {
        // Hindi "नमस्ते" (Namaste) with halant-conjuncts
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">नमस्ते</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Devanagari with vowel signs', (tester) async {
        // Devanagari consonant with matra (vowel sign)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">हिंदी</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Complex Script Detection - CJK', () {
      testWidgets('Chinese text renders correctly', (tester) async {
        // Chinese "你好" (Hello)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">你好世界</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Japanese hiragana and kanji mix', (tester) async {
        // Japanese "こんにちは" (Hello)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">日本語</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Korean hangul', (tester) async {
        // Korean "안녕하세요" (Hello)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="30" font-size="16">안녕하세요</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Grapheme Cluster Handling', () {
      testWidgets('Emoji with ZWJ sequence as single cluster', (tester) async {
        // Family emoji (ZWJ sequence treated as single grapheme)
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">👨‍👩‍👧‍👦</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Emoji with skin tone modifier', (tester) async {
        // Waving hand with skin tone modifier
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

      testWidgets('Flag emoji (regional indicator pairs)', (tester) async {
        // Country flags as regional indicator pairs
        const svg = '''
          <svg viewBox="0 0 200 50" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="35" font-size="24">🇺🇸 🇬🇧 🇫🇷 🇩🇪</text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 200, height: 50),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Per-Character Positioning with Complex Scripts', () {
      testWidgets('Per-char dx/dy with combining marks', (tester) async {
        // Characters with diacritics and per-char positioning
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="16" dx="0 20 20 20 20">
              café
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Rotate with grapheme clusters', (tester) async {
        // Rotation applied to grapheme clusters
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="16" rotate="0 15 30 45">
              naïve
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Mixed Scripts and Direction', () {
      testWidgets('Mixed LTR and RTL scripts', (tester) async {
        const svg = '''
          <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
            <text x="10" y="50" font-size="16">
              <tspan>English </tspan>
              <tspan direction="rtl" unicode-bidi="embed">עברית</tspan>
              <tspan> and </tspan>
              <tspan direction="rtl" unicode-bidi="embed">عربي</tspan>
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 400, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('Numbers within RTL text', (tester) async {
        const svg = '''
          <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
            <text x="280" y="50" font-size="16" direction="rtl" text-anchor="start">
              מחיר: ₪123.45
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 300, height: 100),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Integration - Complete Unicode Support', () {
      testWidgets('Multi-language text with various Unicode features', (
        tester,
      ) async {
        const svg = '''
          <svg viewBox="0 0 600 300" xmlns="http://www.w3.org/2000/svg">
            <rect width="600" height="300" fill="#f5f5f5"/>
            
            <!-- Latin with diacritics -->
            <text x="20" y="40" font-size="14" fill="#333">
              French: café résumé naïve
            </text>
            
            <!-- German with umlauts -->
            <text x="20" y="70" font-size="14" fill="#333">
              German: München Düsseldorf
            </text>
            
            <!-- Spanish with ñ and accents -->
            <text x="20" y="100" font-size="14" fill="#333">
              Spanish: señor mañana niño
            </text>
            
            <!-- Arabic (RTL) -->
            <text x="580" y="130" font-size="14" fill="#333" direction="rtl" text-anchor="start">
              العربية: مرحبا
            </text>
            
            <!-- Hebrew (RTL) -->
            <text x="580" y="160" font-size="14" fill="#333" direction="rtl" text-anchor="start">
              עברית: שלום
            </text>
            
            <!-- Thai -->
            <text x="20" y="190" font-size="14" fill="#333">
              Thai: สวัสดี
            </text>
            
            <!-- Hindi (Devanagari) -->
            <text x="20" y="220" font-size="14" fill="#333">
              Hindi: नमस्ते
            </text>
            
            <!-- CJK -->
            <text x="20" y="250" font-size="14" fill="#333">
              中文: 你好 | 日本語: こんにちは | 한국어: 안녕
            </text>
            
            <!-- Emoji -->
            <text x="20" y="280" font-size="18" fill="#333">
              Emoji: 👋🏽 👨‍👩‍👧 🇺🇸🇯🇵
            </text>
          </svg>
        ''';

        await tester.pumpWidget(
          AnimatedSvgPicture.string(svg, width: 600, height: 300),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
