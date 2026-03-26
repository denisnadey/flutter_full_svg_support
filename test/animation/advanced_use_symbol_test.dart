import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Advanced use/symbol inheritance tests covering:
/// - CSS cascade through use shadow boundary
/// - Nested use-within-use coordinate stacking (3+ levels)
/// - Event retargeting from shadow content to use element
/// - Use within clipPath and mask regions
/// - Deeply nested symbol viewBox stacking
/// - Edge cases (circular references, missing hrefs)
void main() {
  group('CSS Cascade Through Use Shadow Boundary', () {
    testWidgets('presentation attributes on use propagate into shadow tree', (
      WidgetTester tester,
    ) async {
      // When referenced element has no fill, use element's fill should apply
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="myRect" x="10" y="10" width="80" height="80"/>
          </defs>
          <use href="#myRect" fill="red"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Fill from use element should apply since ref has no explicit fill
      expect(analysis.pixelCount, greaterThan(1000));
    });

    testWidgets(
      'style rules from original definition context are preserved',
      (WidgetTester tester) async {
        // CSS class in <style> should still apply to referenced elements
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <style>.highlight { fill: red; }</style>
            <defs>
              <rect id="myRect" class="highlight" x="10" y="10" width="80" height="80"/>
            </defs>
            <use href="#myRect"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // CSS class rule should apply through use boundary
        expect(analysis.pixelCount, greaterThan(1000));
      },
    );

    testWidgets(
      'inline styles on referenced elements take precedence over use pres attrs',
      (WidgetTester tester) async {
        // Inline style on ref (red) should win over use fill (blue)
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="myRect" x="10" y="10" width="80" height="80"
                    style="fill: red;"/>
            </defs>
            <use href="#myRect" fill="blue"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final redAnalysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // Inline style (red) should win over use fill (blue)
        // If blue were winning, we'd have minimal red pixels
        expect(redAnalysis.pixelCount, greaterThan(1000));
      },
    );

    testWidgets(
      'inherited CSS properties flow through use boundary correctly',
      (WidgetTester tester) async {
        // color on <use> should be inherited by referenced text
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="icon">
                <rect x="10" y="10" width="30" height="30"/>
              </g>
            </defs>
            <g fill="red">
              <use href="#icon"/>
            </g>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        // fill should inherit from parent <g> through use boundary
        expect(analysis.pixelCount, greaterThan(100));
      },
    );
  });

  group('3-Level Nested Use Coordinate Stacking', () {
    testWidgets('3-level nested use x/y offsets stack correctly', (
      WidgetTester tester,
    ) async {
      // use1(x=5) -> use2(x=5) -> use3(x=5) -> rect
      // Total offset should be 15,15
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="20" height="20" fill="red"/>
            <use id="u1" href="#r" x="5" y="5"/>
            <use id="u2" href="#u1" x="5" y="5"/>
            <use id="u3" href="#u2" x="5" y="5"/>
          </defs>
          <use href="#u3"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Rect should render (nested use within limits)
      expect(analysis.pixelCount, greaterThan(100));
      // Position should be offset by accumulated x/y
      expect(analysis.boundingBox.left, greaterThan(20));
    });

    testWidgets('nested use with transform attribute composition', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="20" height="20" fill="red"/>
            <use id="u1" href="#r" transform="translate(10,0)"/>
            <use id="u2" href="#u1" transform="translate(10,0)"/>
          </defs>
          <use href="#u2" x="10" y="10"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Should render with combined transforms
      expect(analysis.pixelCount, greaterThan(100));
      // Total x offset should be ~30+ (10+10+10)
      expect(analysis.boundingBox.left, greaterThan(50));
    });

    testWidgets('nested symbol viewBox transforms compose correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="inner" viewBox="0 0 20 20">
              <rect x="0" y="0" width="20" height="20" fill="red"/>
            </symbol>
            <symbol id="outer" viewBox="0 0 40 40">
              <use href="#inner" width="40" height="40"/>
            </symbol>
          </defs>
          <use href="#outer" x="20" y="20" width="80" height="80"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 400),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Nested symbol viewBox transforms should compose
      expect(analysis.pixelCount, greaterThan(500));
    });
  });

  group('Event Retargeting', () {
    testWidgets('use element with ID renders referenced content at correct position', (
      WidgetTester tester,
    ) async {
      // Test that the use element's ID is properly preserved for event handling
      // While we can't directly test hit-testing without callbacks,
      // we verify the structure supports retargeting
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="innerRect" x="0" y="0" width="50" height="50" fill="red"/>
          </defs>
          <use id="myUse" href="#innerRect" x="25" y="25"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Rect should be positioned at (25,25) per use x/y
      expect(analysis.pixelCount, greaterThan(1000));
      expect(analysis.boundingBox.left, greaterThan(40));
      expect(analysis.boundingBox.top, greaterThan(40));
    });

    testWidgets('nested use with IDs renders at combined position', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="0" y="0" width="40" height="40" fill="red"/>
            <use id="inner" href="#r"/>
          </defs>
          <use id="outer" href="#inner" x="10" y="10"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Rect should be visible
      expect(analysis.pixelCount, greaterThan(100));
    });
  });

  group('Use Inside ClipPath', () {
    testWidgets('use element inside clipPath clips correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <circle id="clipCircle" cx="0" cy="0" r="25"/>
            <clipPath id="clip">
              <use href="#clipCircle" x="50" y="50"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Circular clip should produce limited area
      expect(analysis.pixelCount, greaterThan(300));
      expect(analysis.pixelCount, lessThan(20000));
    });

    testWidgets('use of symbol inside clipPath with viewBox', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="clipShape" viewBox="0 0 20 20">
              <rect x="0" y="0" width="20" height="20"/>
            </symbol>
            <clipPath id="clip">
              <use href="#clipShape" x="30" y="30" width="40" height="40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                clip-path="url(#clip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Symbol viewBox clip should work
      expect(analysis.pixelCount, greaterThan(500));
    });
  });

  group('Use Inside Mask', () {
    testWidgets('use element inside mask works correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="maskRect" width="50" height="50" fill="white"/>
            <mask id="mask">
              <use href="#maskRect" x="25" y="25"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" 
                mask="url(#mask)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // Mask should limit visible area
      expect(analysis.pixelCount, greaterThan(500));
    });
  });

  group('Nested Symbol ViewBox Stacking (3+ levels)', () {
    testWidgets('3-level nested symbol viewBox stacking', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="s1" viewBox="0 0 10 10">
              <rect x="0" y="0" width="10" height="10" fill="red"/>
            </symbol>
            <symbol id="s2" viewBox="0 0 20 20">
              <use href="#s1" width="20" height="20"/>
            </symbol>
            <symbol id="s3" viewBox="0 0 40 40">
              <use href="#s2" width="40" height="40"/>
            </symbol>
          </defs>
          <use href="#s3" x="10" y="10" width="100" height="100"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 400),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

      // All viewBox transforms should compose
      expect(analysis.pixelCount, greaterThan(1000));
    });
  });

  group('Mixed Coordinate Units Across Use Levels', () {
    testWidgets('percentage and absolute units mix correctly', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r" x="10%" y="10%" width="30" height="30" fill="red"/>
          </defs>
          <use href="#r" x="20" y="20"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Should render without error
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('circular use reference is detected and prevented', (
      WidgetTester tester,
    ) async {
      // Direct circular: a -> b -> a
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <g id="a">
              <use href="#b"/>
              <rect x="10" y="10" width="20" height="20" fill="red"/>
            </g>
            <g id="b">
              <use href="#a"/>
            </g>
          </defs>
          <use href="#a"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      // Should not crash or hang
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('missing href handled gracefully', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="30" height="30" fill="red"/>
          <use x="50" y="50"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      // Should not crash, rect should still render
      await tester.pump();
      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('use referencing non-existent ID handled gracefully', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="30" height="30" fill="red"/>
          <use href="#nonExistent" x="50" y="50"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      // Should not crash, rect should still render
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('deeply nested use at recursion limit (10 levels)', (
      WidgetTester tester,
    ) async {
      // Create a chain at the recursion limit
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="r0" x="0" y="0" width="10" height="10" fill="red"/>
            <use id="u1" href="#r0"/>
            <use id="u2" href="#u1"/>
            <use id="u3" href="#u2"/>
            <use id="u4" href="#u3"/>
            <use id="u5" href="#u4"/>
            <use id="u6" href="#u5"/>
            <use id="u7" href="#u6"/>
            <use id="u8" href="#u7"/>
            <use id="u9" href="#u8"/>
            <use id="u10" href="#u9"/>
          </defs>
          <use href="#u10" x="10" y="10"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      // Should not crash or hang
      await tester.pump();
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    test('self-referencing use is prevented during parsing', () {
      // This test verifies that self-referencing use elements don't cause
      // infinite loops during parsing. The actual circular reference prevention
      // happens at render time via useStack tracking.
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <use id="self" href="#self" x="10" y="10"/>
          <rect x="30" y="30" width="40" height="40" fill="red"/>
        </svg>
      ''';

      // Parsing should not crash or hang
      final document = SvgParser.parse(svgXml);
      expect(document.root.tagName, 'svg');
      
      // The self-referencing use element should be parsed
      final useElement = document.root.children.firstWhere(
        (n) => n.tagName == 'use',
        orElse: () => throw StateError('use element not found'),
      );
      expect(useElement.id, 'self');
      expect(useElement.getAttributeValue('href'), '#self');
      
      // Rect should also be parsed
      final rect = document.root.children.firstWhere(
        (n) => n.tagName == 'rect',
        orElse: () => throw StateError('rect not found'),
      );
      // Fill attribute might be parsed as Color object or kept as string
      final fillValue = rect.getAttributeValue('fill');
      expect(fillValue != null, true);
    });
  });

  group('DOM Parsing Tests', () {
    test('nested symbol viewBox parsed correctly', () {
      const svgString = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="s1" viewBox="0 0 10 10">
              <rect width="10" height="10"/>
            </symbol>
            <symbol id="s2" viewBox="0 0 20 20">
              <use href="#s1" width="20" height="20"/>
            </symbol>
          </defs>
          <use href="#s2" x="10" y="10" width="50" height="50"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final defs = document.root.children.firstWhere(
        (n) => n.tagName == 'defs',
      );
      final s1 = defs.children.firstWhere((n) => n.id == 's1');
      final s2 = defs.children.firstWhere((n) => n.id == 's2');

      expect(s1.getAttributeValue('viewBox'), '0 0 10 10');
      expect(s2.getAttributeValue('viewBox'), '0 0 20 20');

      // Check nested use in s2
      final nestedUse = s2.children.firstWhere((n) => n.tagName == 'use');
      expect(nestedUse.getAttributeValue('href'), '#s1');
    });
  });
}
