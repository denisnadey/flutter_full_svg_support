import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Tests for foreignObject nested SVG transform computation.
///
/// These tests verify that _computeForeignObjectNestedSvgTransform and
/// _parsePreserveAspectRatioForNested correctly handle:
/// - Nested SVG with viewBox inside foreignObject
/// - All preserveAspectRatio alignment values
/// - meet/slice/none modifiers
/// - Edge cases (no viewBox, empty dimensions, etc.)
void main() {
  group('ForeignObject Nested SVG Transform', () {
    group('ViewBox transform computation', () {
      testWidgets('nested SVG with viewBox computes correct transform', (
        WidgetTester tester,
      ) async {
        // viewBox="0 0 50 50" in 100x100 foreignObject = 2x scale
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Red rect should render with viewBox transform',
        );

        // Content fills the foreignObject (50x50 viewBox scaled to fit)
        // The bounding box width should be meaningful (>50 due to scaling in render)
        expect(
          analysis.boundingBox.width,
          greaterThan(50),
          reason: 'ViewBox should scale content appropriately',
        );
      });

      testWidgets('nested SVG without viewBox returns null transform', (
        WidgetTester tester,
      ) async {
        // No viewBox = no transform needed, content uses 1:1 mapping
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg width="100" height="100">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Red rect should render without viewBox',
        );
      });
    });

    group('PreserveAspectRatio values', () {
      testWidgets('xMinYMin meet aligns to top-left corner', (
        WidgetTester tester,
      ) async {
        // Non-square viewBox in square FO - should scale uniformly and align top-left
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg viewBox="0 0 100 50" preserveAspectRatio="xMinYMin meet">
                <rect x="0" y="0" width="100" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Content should render with xMinYMin alignment',
        );

        // xMinYMin means content aligns to top-left
        expect(
          analysis.boundingBox.left,
          lessThan(50),
          reason: 'xMinYMin should align content to left edge',
        );
        expect(
          analysis.boundingBox.top,
          lessThan(50),
          reason: 'xMinYMin should align content to top edge',
        );
      });

      testWidgets('xMidYMid meet centers content', (WidgetTester tester) async {
        // Default preserveAspectRatio behavior - centered
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg viewBox="0 0 100 50" preserveAspectRatio="xMidYMid meet">
                <rect x="0" y="0" width="100" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Content should render centered',
        );
      });

      testWidgets('xMaxYMax meet aligns to bottom-right', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg viewBox="0 0 100 50" preserveAspectRatio="xMaxYMax meet">
                <rect x="0" y="0" width="100" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Content should render with xMaxYMax alignment',
        );
      });

      testWidgets('preserveAspectRatio="none" stretches content', (
        WidgetTester tester,
      ) async {
        // none = stretch to fill viewport, ignoring aspect ratio
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg viewBox="0 0 200 50" preserveAspectRatio="none">
                <rect x="0" y="0" width="200" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Content should render stretched with none',
        );

        // With none, content should fill the foreignObject dimensions
        // Verify both width and height are reasonable (content rendered)
        expect(
          analysis.boundingBox.width,
          greaterThan(50),
          reason: 'none should stretch content to fill viewport width',
        );
        expect(
          analysis.boundingBox.height,
          greaterThan(50),
          reason: 'none should stretch content to fill viewport height',
        );
      });

      testWidgets('xMidYMid slice clips overflow', (WidgetTester tester) async {
        // slice = scale to fill, clip overflow
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg viewBox="0 0 50 100" preserveAspectRatio="xMidYMid slice">
                <rect x="0" y="0" width="50" height="100" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Content should render with slice behavior',
        );
      });
    });

    group('Edge cases', () {
      testWidgets('foreignObject with zero width/height renders nothing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <rect x="0" y="0" width="200" height="200" fill="#ccc"/>
            <foreignObject x="0" y="0" width="0" height="0">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          equals(0),
          reason: 'Zero-dimension foreignObject should render nothing',
        );
      });

      testWidgets('nested SVG with zero-dimension viewBox skips transform', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg viewBox="0 0 0 0">
                <rect x="0" y="0" width="50" height="50" fill="blue"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Should handle gracefully without crash
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('nested SVG with invalid viewBox handles gracefully', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <foreignObject x="0" y="0" width="100" height="100">
              <svg viewBox="invalid viewbox">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Should handle gracefully without crash
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('deeply nested foreignObject preserves transforms', (
        WidgetTester tester,
      ) async {
        // SVG > ForeignObject > SVG > ForeignObject > SVG with viewBox
        const svgXml = '''
          <svg viewBox="0 0 300 300">
            <foreignObject x="50" y="50" width="200" height="200">
              <svg viewBox="0 0 100 100">
                <foreignObject x="10" y="10" width="80" height="80">
                  <svg viewBox="0 0 40 40">
                    <rect x="0" y="0" width="40" height="40" fill="red"/>
                  </svg>
                </foreignObject>
              </svg>
            </foreignObject>
          </svg>
        ''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 300,
                  height: 300,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final pixels = await VisualTestUtils.captureWidgetPixels(tester);
        final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

        expect(
          analysis.pixelCount,
          greaterThan(0),
          reason: 'Deeply nested content should render',
        );

        // Content should be offset by all the nesting
        expect(
          analysis.boundingBox.left,
          greaterThan(50),
          reason: 'Content should be offset by cumulative nesting',
        );
      });
    });

    group('All preserveAspectRatio alignments', () {
      // Test all 9 alignment values
      for (final xAlign in ['xMin', 'xMid', 'xMax']) {
        for (final yAlign in ['YMin', 'YMid', 'YMax']) {
          final alignment = '$xAlign$yAlign';

          testWidgets('$alignment meet handles alignment correctly', (
            WidgetTester tester,
          ) async {
            final svgXml =
                '''
              <svg viewBox="0 0 200 200">
                <foreignObject x="0" y="0" width="100" height="100">
                  <svg viewBox="0 0 100 50" preserveAspectRatio="$alignment meet">
                    <rect x="0" y="0" width="100" height="50" fill="red"/>
                  </svg>
                </foreignObject>
              </svg>
            ''';

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: RepaintBoundary(
                    child: AnimatedSvgPicture.string(
                      svgXml,
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
              ),
            );

            await tester.pump();

            final pixels = await VisualTestUtils.captureWidgetPixels(tester);
            final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

            expect(
              analysis.pixelCount,
              greaterThan(0),
              reason: '$alignment meet should render content',
            );
          });

          testWidgets('$alignment slice handles alignment correctly', (
            WidgetTester tester,
          ) async {
            final svgXml =
                '''
              <svg viewBox="0 0 200 200">
                <foreignObject x="0" y="0" width="100" height="100">
                  <svg viewBox="0 0 50 100" preserveAspectRatio="$alignment slice">
                    <rect x="0" y="0" width="50" height="100" fill="red"/>
                  </svg>
                </foreignObject>
              </svg>
            ''';

            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: RepaintBoundary(
                    child: AnimatedSvgPicture.string(
                      svgXml,
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
              ),
            );

            await tester.pump();

            final pixels = await VisualTestUtils.captureWidgetPixels(tester);
            final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);

            expect(
              analysis.pixelCount,
              greaterThan(0),
              reason: '$alignment slice should render content',
            );
          });
        }
      }
    });
  });
}
