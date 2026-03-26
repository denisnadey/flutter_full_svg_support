import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/animated_svg_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FontFallbackResult', () {
    test('empty result when no fonts specified', () {
      const result = FontFallbackResult();

      expect(result.primaryFont, isNull);
      expect(result.fallbackFonts, isEmpty);
      expect(result.isEmpty, isTrue);
      expect(result.isNotEmpty, isFalse);
      expect(result.toFontList(), isEmpty);
    });

    test('primary font only', () {
      const result = FontFallbackResult(primaryFont: 'Arial');

      expect(result.primaryFont, 'Arial');
      expect(result.fallbackFonts, isEmpty);
      expect(result.isEmpty, isFalse);
      expect(result.isNotEmpty, isTrue);
      expect(result.toFontList(), ['Arial']);
    });

    test('primary font with fallbacks', () {
      const result = FontFallbackResult(
        primaryFont: 'Helvetica',
        fallbackFonts: ['Arial', 'sans-serif'],
      );

      expect(result.primaryFont, 'Helvetica');
      expect(result.fallbackFonts, ['Arial', 'sans-serif']);
      expect(result.isEmpty, isFalse);
      expect(result.toFontList(), ['Helvetica', 'Arial', 'sans-serif']);
    });

    test('equality comparison', () {
      const result1 = FontFallbackResult(
        primaryFont: 'Arial',
        fallbackFonts: ['Helvetica'],
      );
      const result2 = FontFallbackResult(
        primaryFont: 'Arial',
        fallbackFonts: ['Helvetica'],
      );
      const result3 = FontFallbackResult(
        primaryFont: 'Arial',
        fallbackFonts: ['sans-serif'],
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('hashCode consistency', () {
      const result1 = FontFallbackResult(
        primaryFont: 'Arial',
        fallbackFonts: ['Helvetica'],
      );
      const result2 = FontFallbackResult(
        primaryFont: 'Arial',
        fallbackFonts: ['Helvetica'],
      );

      expect(result1.hashCode, equals(result2.hashCode));
    });

    test('toString representation', () {
      const empty = FontFallbackResult();
      const single = FontFallbackResult(primaryFont: 'Arial');
      const full = FontFallbackResult(
        primaryFont: 'Arial',
        fallbackFonts: ['Helvetica'],
      );

      expect(empty.toString(), 'FontFallbackResult(empty)');
      expect(single.toString(), contains('Arial'));
      expect(full.toString(), contains('Arial'));
      expect(full.toString(), contains('Helvetica'));
    });
  });

  group('SVG text font-family rendering', () {
    testWidgets('single font family renders without error', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="Arial">
            Single Font Family
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('multiple font families comma-separated', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" 
                font-family="Helvetica, Arial, sans-serif">
            Fallback Chain
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('quoted font names with spaces (double quotes)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" 
                font-family='"Times New Roman", Georgia, serif'>
            Quoted Font Name
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 350, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('quoted font names with spaces (single quotes)', (
      tester,
    ) async {
      const svg = """
        <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" 
                font-family="'Courier New', Consolas, monospace">
            Single Quoted Name
          </text>
        </svg>
      """;

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 350, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mixed quoted and unquoted font names', (tester) async {
      const svg = """
        <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" 
                font-family='"Helvetica Neue", Arial, "Open Sans", sans-serif'>
            Mixed Quotes
          </text>
        </svg>
      """;

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 350, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('generic family names - serif', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="serif">
            Serif Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('generic family names - sans-serif', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="sans-serif">
            Sans-Serif Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('generic family names - monospace', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="monospace">
            Monospace Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('generic family at end of chain (common pattern)', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" 
                font-family="Roboto, Helvetica, Arial, sans-serif">
            Generic at End
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 350, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('empty font-family uses default', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="">
            Empty Font Family
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font family with extra whitespace', (tester) async {
      const svg = '''
        <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" 
                font-family="  Arial  ,  Helvetica  ,  sans-serif  ">
            Whitespace Test
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 350, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('system-ui generic family', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="system-ui">
            System UI Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('cursive generic family', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="cursive">
            Cursive Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('fantasy generic family', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="fantasy">
            Fantasy Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-family via style attribute', (tester) async {
      const svg = '''
        <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" 
                style="font-family: Georgia, Times, serif">
            Style Attribute
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 350, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-family inherited from parent group', (tester) async {
      const svg = '''
        <svg viewBox="0 0 350 100" xmlns="http://www.w3.org/2000/svg">
          <g font-family="Georgia, serif">
            <text x="10" y="30" font-size="20">Inherited Font 1</text>
            <text x="10" y="60" font-size="20">Inherited Font 2</text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 350, height: 100),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('complex fallback chain with all types', (tester) async {
      const svg = """
        <svg viewBox="0 0 400 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="18" 
                font-family='"Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif'>
            Complex Fallback Chain
          </text>
        </svg>
      """;

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 400, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-family with only whitespace uses default', (
      tester,
    ) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="   ">
            Whitespace Only
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ui-serif modern CSS generic family', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="ui-serif">
            UI Serif Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ui-monospace modern CSS generic family', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" font-family="ui-monospace">
            UI Monospace Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        AnimatedSvgPicture.string(svg, width: 300, height: 50),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font family with special characters in name', (tester) async {
      const svg = '''
        <svg viewBox="0 0 350 50" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="30" font-size="20" 
                font-family='"Source Code Pro", monospace'>
            Special Characters
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
}
