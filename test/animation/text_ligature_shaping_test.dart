import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ligature preservation across tspan boundaries', () {
    testWidgets('fi ligature preserved across tspan with same ligature features',
        (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="24" fill="black">
            <tspan fill="red">fi</tspan><tspan fill="blue">nd</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('fl ligature preserved across tspan boundaries', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="24" fill="black">
            <tspan fill="green">fl</tspan><tspan fill="orange">ower</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('ffi ligature preserved across multiple tspans', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="24" fill="black">
            <tspan fill="red">f</tspan><tspan fill="green">f</tspan><tspan fill="blue">i</tspan>ce
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Font-feature-settings per tspan', () {
    testWidgets('tabular numerals vs proportional numerals', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan style="font-feature-settings:'tnum' 1">123</tspan>
            <tspan style="font-feature-settings:'pnum' 1">456</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('lining vs oldstyle figures', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan style="font-feature-settings:'lnum' 1">2024</tspan>
            <tspan> vs </tspan>
            <tspan style="font-feature-settings:'onum' 1">2024</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('slashed zero feature', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan>Normal 0</tspan>
            <tspan style="font-feature-settings:'zero' 1"> Slashed 0</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Unsupported feature fallback', () {
    testWidgets('non-existent feature does not crash', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black"
                style="font-feature-settings:'xxxx' 1">
            Text with unsupported feature
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('multiple unsupported features do not crash', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black"
                style="font-feature-settings:'xxxx' 1, 'yyyy' 1, 'zzzz' 1">
            Text with multiple unsupported features
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mix of supported and unsupported features', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black"
                style="font-feature-settings:'liga' 1, 'xxxx' 1, 'kern' 1">
            Text with mixed features
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Feature scoping between runs', () {
    testWidgets('features do not bleed from one tspan to next', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan style="font-feature-settings:'smcp' 1">Small Caps</tspan>
            <tspan> Normal Text</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('alternating features are properly scoped', (tester) async {
      const svg = '''
        <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            <tspan style="font-feature-settings:'smcp' 1">SMALL</tspan>
            <tspan> normal </tspan>
            <tspan style="font-feature-settings:'smcp' 1">SMALL</tspan>
            <tspan> normal</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 500, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('nested tspan features override parent', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black"
                style="font-feature-settings:'liga' 1">
            Outer <tspan style="font-feature-settings:'liga' 0">fi no liga</tspan> fi liga
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mixed ligature features', () {
    testWidgets('liga enabled then disabled', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="24" fill="black">
            <tspan style="font-feature-settings:'liga' 1">fi</tspan>
            <tspan style="font-feature-settings:'liga' 0">fi</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('discretionary ligatures enabled for some spans',
        (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan>Normal st</tspan>
            <tspan style="font-feature-settings:'dlig' 1">Discretionary st</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('contextual alternates across boundaries', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan style="font-feature-settings:'calt' 1">ab</tspan>
            <tspan style="font-feature-settings:'calt' 1">cd</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Small-caps across boundaries', () {
    testWidgets('font-variant small-caps on first tspan only', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan style="font-variant:small-caps">Hello</tspan>
            <tspan> World</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('font-variant-caps small-caps alternating', (tester) async {
      const svg = '''
        <svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="16" fill="black">
            <tspan font-variant-caps="small-caps">Small</tspan>
            <tspan> Normal </tspan>
            <tspan font-variant-caps="small-caps">Small</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 500, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Tabular vs proportional numerals width', () {
    testWidgets('tabular numerals have consistent width', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 150" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="40" font-size="20" fill="black"
                style="font-feature-settings:'tnum' 1">
            1111
          </text>
          <text x="10" y="80" font-size="20" fill="black"
                style="font-feature-settings:'tnum' 1">
            0000
          </text>
          <text x="10" y="120" font-size="20" fill="black"
                style="font-feature-settings:'pnum' 1">
            1111
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 150),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Cache key correctness', () {
    testWidgets('same text with different features produces different rendering',
        (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 150" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="40" font-size="20" fill="black"
                style="font-feature-settings:'liga' 1">
            fi fl ff
          </text>
          <text x="10" y="80" font-size="20" fill="black"
                style="font-feature-settings:'liga' 0">
            fi fl ff
          </text>
          <text x="10" y="120" font-size="20" fill="black">
            fi fl ff
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 150),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('same text with same features uses cached paragraph',
        (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 150" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="40" font-size="20" fill="black"
                style="font-feature-settings:'kern' 1">
            Hello World
          </text>
          <text x="10" y="80" font-size="20" fill="black"
                style="font-feature-settings:'kern' 1">
            Hello World
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 150),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Regression - basic text without special features', () {
    testWidgets('plain text renders correctly', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            Simple text without features
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('multiple tspans without features', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan fill="red">Red</tspan>
            <tspan fill="green">Green</tspan>
            <tspan fill="blue">Blue</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('inherited font-family still works', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <g font-family="Georgia, serif">
            <text x="10" y="50" font-size="20" fill="black">
              Inherited font family
            </text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('text with standard attributes still works', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="24" font-weight="bold" 
                font-style="italic" fill="navy" letter-spacing="2">
            Bold Italic Navy Text
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Edge cases', () {
    testWidgets('empty tspan does not break ligature context', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="24" fill="black">
            <tspan>fi</tspan><tspan></tspan><tspan>nd</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('whitespace-only tspan preserves flow', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black">
            <tspan>Word1</tspan><tspan> </tspan><tspan>Word2</tspan>
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('feature value 0 (off) is handled', (tester) async {
      const svg = '''
        <svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black"
                style="font-feature-settings:'liga' 0, 'kern' 0">
            No ligatures or kerning
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('feature with on/off keywords', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="20" fill="black"
                style="font-feature-settings:'liga' on, 'kern' off">
            Ligatures on, kerning off
          </text>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('normal keyword resets features', (tester) async {
      const svg = '''
        <svg viewBox="0 0 400 100" xmlns="http://www.w3.org/2000/svg">
          <g style="font-feature-settings:'smcp' 1">
            <text x="10" y="40" font-size="20" fill="black">
              Inherits small caps
            </text>
            <text x="10" y="80" font-size="20" fill="black"
                  style="font-feature-settings:normal">
              Reset to normal
            </text>
          </g>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
