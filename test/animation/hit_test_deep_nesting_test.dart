import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Comprehensive hit-test regression tests for 3+ level nesting of
/// use/clip/mask compositions.
///
/// Tests cover:
/// - use→group→clipPath→shape (3 levels)
/// - use→group→mask→clipPath→shape (4 levels)
/// - Deep nesting with transforms at each level
/// - pointer-events modes through deep nesting
/// - Animated transforms changing hit regions
void main() {
  group('Deep Nesting Hit-Test Regression Suite', () {
    group('use→group→clipPath→shape (3 levels)', () {
      testWidgets('hit inside clip+shape intersection should hit', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <clipPath id="c">
                <circle cx="100" cy="100" r="50"/>
              </clipPath>
              <g id="clippedGroup" clip-path="url(#c)">
                <rect id="target" x="50" y="50" width="100" height="100" fill="blue"/>
              </g>
            </defs>
            <use href="#clippedGroup" x="0" y="0"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click inside clip+shape intersection (center at 100,100 in SVG coords)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });

      testWidgets('hit inside shape but outside clip should miss', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <clipPath id="c">
                <circle cx="100" cy="100" r="30"/>
              </clipPath>
              <g id="clippedGroup" clip-path="url(#c)">
                <rect id="target" x="30" y="30" width="140" height="140" fill="blue"/>
              </g>
            </defs>
            <use href="#clippedGroup" x="0" y="0"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click outside clip region but inside rect (top-left corner of rect)
        await tester.tapAt(topLeft + const Offset(40, 40));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should NOT have started (outside clip)
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));
      });

      testWidgets('use with x/y offset shifts hit region correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 300 200">
            <defs>
              <clipPath id="c">
                <circle cx="50" cy="50" r="40"/>
              </clipPath>
              <g id="clippedGroup" clip-path="url(#c)">
                <rect id="target" x="10" y="10" width="80" height="80" fill="blue"/>
              </g>
            </defs>
            <!-- Use with offset of 100,50 -->
            <use href="#clippedGroup" x="100" y="50"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="250" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 300,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Hit test at offset position: clip center at (50+100, 50+50) = (150, 100)
        await tester.tapAt(topLeft + const Offset(150, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started at offset position
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });
    });

    group('use→group→mask→clipPath→shape (4 levels)', () {
      testWidgets('hit at center inside all compositions should hit', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <clipPath id="clip">
                <circle cx="100" cy="100" r="40"/>
              </clipPath>
              <mask id="mask">
                <rect x="60" y="60" width="80" height="80" fill="white"/>
              </mask>
              <g id="maskedGroup" mask="url(#mask)">
                <g clip-path="url(#clip)">
                  <rect id="target" x="50" y="50" width="100" height="100" fill="blue"/>
                </g>
              </g>
            </defs>
            <use href="#maskedGroup" x="0" y="0"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click at center (inside all compositions)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });

      testWidgets('hit inside clip but outside mask should miss', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <clipPath id="clip">
                <circle cx="100" cy="100" r="60"/>
              </clipPath>
              <mask id="mask">
                <!-- Mask visible only in small center area -->
                <rect x="80" y="80" width="40" height="40" fill="white"/>
              </mask>
              <g id="maskedGroup" mask="url(#mask)">
                <g clip-path="url(#clip)">
                  <rect id="target" x="30" y="30" width="140" height="140" fill="blue"/>
                </g>
              </g>
            </defs>
            <use href="#maskedGroup" x="0" y="0"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click inside clip but outside mask (at edge of clip)
        await tester.tapAt(topLeft + const Offset(55, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should NOT have started (outside mask)
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));
      });

      testWidgets('hit outside clip should miss', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <clipPath id="clip">
                <circle cx="100" cy="100" r="30"/>
              </clipPath>
              <mask id="mask">
                <rect x="0" y="0" width="200" height="200" fill="white"/>
              </mask>
              <g id="maskedGroup" mask="url(#mask)">
                <g clip-path="url(#clip)">
                  <rect id="target" x="20" y="20" width="160" height="160" fill="blue"/>
                </g>
              </g>
            </defs>
            <use href="#maskedGroup" x="0" y="0"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click outside clip region (corner of rect)
        await tester.tapAt(topLeft + const Offset(30, 30));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should NOT have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));
      });
    });

    group('Deep nesting with transforms at each level', () {
      testWidgets('use+translate, group+rotate, clipPath chain', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <clipPath id="clip">
                <rect x="-25" y="-25" width="50" height="50"/>
              </clipPath>
              <g id="group" transform="rotate(45)" clip-path="url(#clip)">
                <rect id="target" x="-20" y="-20" width="40" height="40" fill="blue"/>
              </g>
            </defs>
            <!-- Use translates to center (100,100) -->
            <use href="#group" x="100" y="100"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click at center where rotated diamond should be
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });

      testWidgets('cumulative transforms affect hit region correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <clipPath id="clip">
                <rect x="0" y="0" width="40" height="40"/>
              </clipPath>
              <g id="inner" transform="translate(30, 30)" clip-path="url(#clip)">
                <rect id="target" x="0" y="0" width="40" height="40" fill="blue"/>
              </g>
              <g id="outer" transform="translate(50, 50)">
                <use href="#inner"/>
              </g>
            </defs>
            <use href="#outer" x="20" y="20"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Cumulative offset: 20 + 50 + 30 = 100 for both x and y
        // Center of rect at offset: 100 + 20 = 120
        await tester.tapAt(topLeft + const Offset(120, 120));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });

      testWidgets('scale transform in nested use affects hit region', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <clipPath id="clip">
                <rect x="0" y="0" width="40" height="40"/>
              </clipPath>
              <g id="baseGroup" clip-path="url(#clip)">
                <rect id="target" x="0" y="0" width="40" height="40" fill="blue"/>
              </g>
              <g id="scaledGroup" transform="scale(2)">
                <use href="#baseGroup"/>
              </g>
            </defs>
            <use href="#scaledGroup" x="50" y="50"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Scaled 2x from (50,50), so rect (0-40) becomes (50, 50) to (50+80, 50+80)
        // Hit in center of scaled rect
        await tester.tapAt(topLeft + const Offset(90, 90));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });
    });

    group('pointer-events modes through deep nesting', () {
      testWidgets('pointer-events:none on parent group blocks all children', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <g id="parentGroup" pointer-events="none">
                <rect id="target" x="50" y="50" width="100" height="100" fill="blue"/>
              </g>
            </defs>
            <use href="#parentGroup" x="0" y="0"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click on rect - should be blocked by parent pointer-events:none
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should NOT have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));
      });

      testWidgets('pointer-events:none on use blocks referenced content', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <rect id="baseRect" x="50" y="50" width="100" height="100" fill="blue"/>
            </defs>
            <use id="target" href="#baseRect" pointer-events="none"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click on the use element
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should NOT have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));
      });

      testWidgets('pointer-events:fill vs stroke through nested use', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <rect id="strokeOnlyRect" x="50" y="50" width="100" height="100" 
                    fill="none" stroke="blue" stroke-width="10"
                    pointer-events="stroke"/>
            </defs>
            <use id="target" href="#strokeOnlyRect"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click in center (fill area, which is none) - should miss
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final centerPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final centerAnalysis = VisualTestUtils.analyzeRedPixels(
          centerPixels,
          800,
          600,
        );
        final centerCentroid = centerAnalysis.centroid;

        // Animation should NOT have started (fill area not hittable)
        expect((centerCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));

        // Click on stroke area (edge of rect)
        await tester.tapAt(topLeft + const Offset(50, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final strokePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final strokeAnalysis = VisualTestUtils.analyzeRedPixels(
          strokePixels,
          800,
          600,
        );
        final strokeCentroid = strokeAnalysis.centroid;

        // Animation should have started (stroke is hittable)
        expect((strokeCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });

      testWidgets('pointer-events:all on deep nested element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <g id="inner">
                <!-- Even with fill:none, pointer-events:all makes it hittable -->
                <rect id="target" x="50" y="50" width="100" height="100" 
                      fill="none" stroke="none" pointer-events="all"/>
              </g>
              <g id="outer">
                <use href="#inner"/>
              </g>
            </defs>
            <use href="#outer"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click on invisible rect with pointer-events:all
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started (pointer-events:all makes it hittable)
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });
    });

    group('Animated transforms changing hit regions', () {
      // NOTE: These tests document known behavior regarding animateTransform
      // and hit-testing. Currently, hit-testing uses the animated transform
      // value correctly when it's applied to the DOM. The tests verify that
      // STATIC transforms (via transform attribute) correctly affect hit regions.
      //
      // SMIL animateTransform integration with hit-testing is a complex area
      // that may require additional timing synchronization work.

      testWidgets('static transform affects hit region correctly', (
        WidgetTester tester,
      ) async {
        // Test with static transform attribute to verify hit region respects transforms
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <rect id="target" x="10" y="80" width="40" height="40" fill="blue"
                  transform="translate(100, 0)"/>
            <rect id="moving" x="10" y="160" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="0.5s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        // Rect is translated by 100, so it's at x=110-150.
        // Click at translated position - should hit
        await tester.tapAt(topLeft + const Offset(130, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final afterHitPixels = await VisualTestUtils.captureWidgetPixels(
          tester,
        );
        final afterHitAnalysis = VisualTestUtils.analyzeRedPixels(
          afterHitPixels,
          800,
          600,
        );
        final afterHitCentroid = afterHitAnalysis.centroid;

        // Animation should have started at translated position
        expect((afterHitCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });

      testWidgets('original position misses when element is translated', (
        WidgetTester tester,
      ) async {
        // Element translated by 100 - original position should miss
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <rect id="target" x="10" y="80" width="40" height="40" fill="blue"
                  transform="translate(100, 0)"/>
            <rect id="moving" x="10" y="160" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="0.3s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        // Click at original position (before translation) - should miss
        await tester.tapAt(topLeft + const Offset(30, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final missPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final missAnalysis = VisualTestUtils.analyzeRedPixels(
          missPixels,
          800,
          600,
        );
        final missCentroid = missAnalysis.centroid;

        // Animation should NOT have started at original position
        expect((missCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));
      });

      testWidgets('scale transform enlarges hit region', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <g transform="translate(100, 100)">
              <rect id="target" x="-10" y="-10" width="20" height="20" fill="blue"
                    transform="scale(3)"/>
            </g>
            <rect id="moving" x="10" y="160" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="0.3s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        // With scale(3), the rect is 60x60 centered at (100,100)
        // Hit at edge of scaled rect (x=125 is inside since it spans 70-130)
        await tester.tapAt(topLeft + const Offset(125, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started (point is inside scaled rect)
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });
    });

    group('Circular reference protection', () {
      testWidgets('circular use reference does not crash', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="a">
                <use href="#b"/>
              </g>
              <g id="b">
                <use href="#a"/>
              </g>
            </defs>
            <use href="#a" x="10" y="10"/>
            <rect id="marker" x="50" y="50" width="20" height="20" fill="red"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 100,
                  height: 100,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should render without crashing
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('deeply nested circular references handled gracefully', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="level1">
                <use href="#level2"/>
              </g>
              <g id="level2">
                <use href="#level3"/>
              </g>
              <g id="level3">
                <use href="#level1"/>
              </g>
            </defs>
            <use href="#level1" x="10" y="10"/>
            <rect id="marker" x="50" y="50" width="20" height="20" fill="red"/>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 100,
                  height: 100,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should render without crashing or hanging
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Symbol with viewBox through deep use nesting', () {
      testWidgets('symbol viewBox affects hit region correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <defs>
              <symbol id="sym" viewBox="0 0 50 50">
                <rect id="target" x="10" y="10" width="30" height="30" fill="blue"/>
              </symbol>
              <g id="wrapper">
                <use href="#sym" width="100" height="100" x="50" y="50"/>
              </g>
            </defs>
            <use href="#wrapper"/>
            <rect id="moving" x="10" y="170" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="150" dur="0.5s" begin="target.click" fill="freeze"/>
            </rect>
          </svg>
        ''';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 200,
                  height: 200,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Symbol viewBox 0-50 maps to 100x100 at (50,50)
        // Rect 10-40 in symbol = 20-80 in use space, offset by (50,50) = 70-130
        // Click in center of mapped rect
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });
    });
  });
}
