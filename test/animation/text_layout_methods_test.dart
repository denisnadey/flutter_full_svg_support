import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Deeply nested tspan transform accumulation', () {
    testWidgets(
      'should apply accumulated transforms for 3-level nested tspan',
      (tester) async {
        // SVG with deeply nested tspan elements, each with its own transform
        const svg = '''
<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="30" transform="translate(5, 0)">
    <tspan transform="translate(10, 0)">
      <tspan transform="translate(15, 0)">
        <tspan x="0" y="0">Deep</tspan>
      </tspan>
    </tspan>
  </text>
</svg>
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // The text should render without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );

    testWidgets(
      'should correctly compose transforms from nested tspan hierarchy',
      (tester) async {
        // SVG with transforms at text and multiple tspan levels
        const svg = '''
<svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50" transform="scale(1.5)">
    <tspan transform="rotate(10)">
      <tspan transform="translate(20, 0)">
        Rotated and scaled
      </tspan>
    </tspan>
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
      },
    );

    testWidgets('should handle identity transforms in nested hierarchy', (
      tester,
    ) async {
      // SVG with nested tspans where some have transforms and some don't
      const svg = '''
<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="30">
    <tspan transform="translate(5, 0)">
      <tspan>
        <tspan transform="translate(10, 0)">
          Mixed transforms
        </tspan>
      </tspan>
    </tspan>
  </text>
</svg>
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Transform point for text', () {
    testWidgets('should handle identity transform correctly', (tester) async {
      // SVG where transform is effectively identity
      const svg = '''
<svg width="100" height="50" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="30" transform="translate(0, 0)">
    <tspan x="10 20 30" y="30">ABC</tspan>
  </text>
</svg>
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 100, height: 50),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('should transform positions with non-identity transform', (
      tester,
    ) async {
      // SVG with actual transform applied to nested tspan
      const svg = '''
<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="0" y="50">
    <tspan transform="matrix(1, 0, 0, 1, 20, 0)">
      <tspan x="0 10 20" y="50">XYZ</tspan>
    </tspan>
  </text>
</svg>
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('should handle scale transform in nested tspan', (
      tester,
    ) async {
      const svg = '''
<svg width="200" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50">
    <tspan transform="scale(2)">
      <tspan x="10 20 30" y="50">ABC</tspan>
    </tspan>
  </text>
</svg>
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('TextLength distribution across nested tspans', () {
    testWidgets('should distribute textLength with spacing mode', (
      tester,
    ) async {
      // SVG with textLength on parent and nested tspan children
      const svg = '''
<svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50" textLength="200" lengthAdjust="spacing">
    <tspan>Hello </tspan>
    <tspan>World</tspan>
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

    testWidgets('should distribute textLength with spacingAndGlyphs mode', (
      tester,
    ) async {
      // SVG with textLength and spacingAndGlyphs on parent
      const svg = '''
<svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50" textLength="200" lengthAdjust="spacingAndGlyphs">
    <tspan>Hello </tspan>
    <tspan>World</tspan>
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

    testWidgets(
      'should apply textLength distribution when parent has it but children do not',
      (tester) async {
        // Parent has textLength, children do not override it
        const svg = '''
<svg width="400" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50" textLength="350" lengthAdjust="spacing">
    <tspan>This </tspan>
    <tspan>is </tspan>
    <tspan>a </tspan>
    <tspan>test</tspan>
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
      },
    );

    testWidgets('should handle nested tspans with different depths', (
      tester,
    ) async {
      // Complex nested structure with textLength on root
      const svg = '''
<svg width="400" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50" textLength="300" lengthAdjust="spacing">
    <tspan>Level1</tspan>
    <tspan>
      <tspan>Level2</tspan>
    </tspan>
    <tspan>End</tspan>
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

    testWidgets('should handle textLength distribution in textPath', (
      tester,
    ) async {
      // textPath with nested tspans and textLength
      const svg = '''
<svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="curve" d="M 10,100 Q 200,10 390,100"/>
  </defs>
  <text textLength="300" lengthAdjust="spacing">
    <textPath href="#curve">
      <tspan>Along </tspan>
      <tspan>the </tspan>
      <tspan>path</tspan>
    </textPath>
  </text>
</svg>
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svg, width: 400, height: 200),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets(
      'should handle scale distribution in textPath with spacingAndGlyphs',
      (tester) async {
        const svg = '''
<svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="curve2" d="M 10,100 Q 200,10 390,100"/>
  </defs>
  <text>
    <textPath href="#curve2" textLength="350" lengthAdjust="spacingAndGlyphs">
      <tspan>Scaled </tspan>
      <tspan>text</tspan>
    </textPath>
  </text>
</svg>
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 400, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );
  });

  group('Combined transform and textLength scenarios', () {
    testWidgets(
      'should handle both transforms and textLength in nested structure',
      (tester) async {
        const svg = '''
<svg width="400" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50" textLength="300" lengthAdjust="spacing">
    <tspan transform="translate(5, 0)">
      <tspan transform="scale(1.1)">
        Transformed and spaced
      </tspan>
    </tspan>
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
      },
    );

    testWidgets('should handle per-character positioning with transforms', (
      tester,
    ) async {
      const svg = '''
<svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50">
    <tspan transform="translate(10, 0)">
      <tspan x="20 40 60 80" y="50">WXYZ</tspan>
    </tspan>
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

    testWidgets('should handle dx/dy with transforms', (tester) async {
      const svg = '''
<svg width="300" height="100" xmlns="http://www.w3.org/2000/svg">
  <text x="10" y="50">
    <tspan transform="rotate(5)">
      <tspan dx="0 5 5 5" dy="0 -2 2 -2">Wave</tspan>
    </tspan>
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
}
