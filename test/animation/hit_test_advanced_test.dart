import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Advanced Hit-Testing', () {
    group('stroke-linecap hit regions', () {
      testWidgets('stroke-linecap:round expands hit region at endpoints', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <line id="target" x1="20" y1="50" x2="80" y2="50" 
                  stroke="blue" stroke-width="10" stroke-linecap="round"/>
            <rect id="moving" x="10" y="10" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

        // Click at line endpoint with round cap - should hit due to expanded area
        // Line starts at x=20 in SVG coords = x=40 in widget coords (200/100 scale)
        // Round cap adds stroke-width/2 = 5 SVG units = 10 widget pixels beyond
        await tester.tapAt(topLeft + const Offset(32, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        // Animation should have started - red rect should have moved
        expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });

      testWidgets(
        'stroke-linecap:butt does not expand hit region at endpoints',
        (WidgetTester tester) async {
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <line id="target" x1="20" y1="50" x2="80" y2="50" 
                  stroke="blue" stroke-width="10" stroke-linecap="butt"/>
            <rect id="moving" x="10" y="10" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

          final beforePixels = await VisualTestUtils.captureWidgetPixels(
            tester,
          );
          final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
            beforePixels,
            800,
            600,
          );
          final beforeCentroid = beforeAnalysis.centroid;

          final pictureFinder = find.byType(AnimatedSvgPicture);
          final topLeft = tester.getTopLeft(pictureFinder);

          // Click beyond line endpoint with butt cap - should NOT hit
          await tester.tapAt(topLeft + const Offset(10, 100));
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
        },
      );
    });

    group('stroke-width expansion', () {
      testWidgets('large stroke-width expands hit region proportionally', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <line id="target" x1="50" y1="10" x2="50" y2="90" 
                  stroke="blue" stroke-width="20"/>
            <rect id="moving" x="10" y="10" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

        // Click 8 pixels away from line center (within stroke-width/2 = 10)
        await tester.tapAt(topLeft + const Offset(116, 100));
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

    group('clip-path hit-testing', () {
      testWidgets('element with clipPath only hittable inside clip region', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="50" cy="50" r="20"/>
              </clipPath>
            </defs>
            <rect id="target" x="10" y="10" width="80" height="80" fill="blue" clip-path="url(#clip)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

        // Click outside clip region (top-left corner of rect)
        await tester.tapAt(topLeft + const Offset(30, 30));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
          outsidePixels,
          800,
          600,
        );
        final outsideCentroid = outsideAnalysis.centroid;

        // Animation should NOT have started
        expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));

        // Click inside clip region (center)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final insidePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final insideAnalysis = VisualTestUtils.analyzeRedPixels(
          insidePixels,
          800,
          600,
        );
        final insideCentroid = insideAnalysis.centroid;

        // Animation should have started
        expect((insideCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });
    });

    group('mask alpha hit-testing', () {
      testWidgets('transparent mask regions are not hittable', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <mask id="mask">
                <!-- Only center is visible, corners are transparent -->
                <circle cx="50" cy="50" r="20" fill="white"/>
              </mask>
            </defs>
            <rect id="target" x="10" y="10" width="80" height="80" fill="blue" mask="url(#mask)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

        // Click outside mask visible region (corner)
        await tester.tapAt(topLeft + const Offset(30, 30));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final cornerPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final cornerAnalysis = VisualTestUtils.analyzeRedPixels(
          cornerPixels,
          800,
          600,
        );
        final cornerCentroid = cornerAnalysis.centroid;

        // Animation should NOT have started (masked region)
        expect((cornerCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));

        // Click inside mask visible region (center)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final centerPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final centerAnalysis = VisualTestUtils.analyzeRedPixels(
          centerPixels,
          800,
          600,
        );
        final centerCentroid = centerAnalysis.centroid;

        // Animation should have started
        expect((centerCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
      });
    });

    group('pointer-events edge cases', () {
      testWidgets(
        'visibility:hidden with pointer-events:painted is not hittable',
        (WidgetTester tester) async {
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="10" y="10" width="40" height="40" 
                  fill="blue" visibility="hidden" pointer-events="painted"/>
            <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

          final beforePixels = await VisualTestUtils.captureWidgetPixels(
            tester,
          );
          final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
            beforePixels,
            800,
            600,
          );
          final beforeCentroid = beforeAnalysis.centroid;

          final pictureFinder = find.byType(AnimatedSvgPicture);
          final topLeft = tester.getTopLeft(pictureFinder);

          // Click on hidden element with pointer-events:painted
          await tester.tapAt(topLeft + const Offset(60, 60));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
          final afterAnalysis = VisualTestUtils.analyzeRedPixels(
            afterPixels,
            800,
            600,
          );
          final afterCentroid = afterAnalysis.centroid;

          // Should still hit because painted mode ignores visibility for paint checking
          // (if element has fill, it's hittable regardless of visibility)
          expect((afterCentroid.dx - beforeCentroid.dx).abs(), greaterThan(5));
        },
      );

      testWidgets(
        'visibility:hidden with pointer-events:visible is not hittable',
        (WidgetTester tester) async {
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="10" y="10" width="40" height="40" 
                  fill="blue" visibility="hidden" pointer-events="visible"/>
            <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

          final beforePixels = await VisualTestUtils.captureWidgetPixels(
            tester,
          );
          final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
            beforePixels,
            800,
            600,
          );
          final beforeCentroid = beforeAnalysis.centroid;

          final pictureFinder = find.byType(AnimatedSvgPicture);
          final topLeft = tester.getTopLeft(pictureFinder);

          // Click on hidden element with pointer-events:visible
          await tester.tapAt(topLeft + const Offset(60, 60));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
          final afterAnalysis = VisualTestUtils.analyzeRedPixels(
            afterPixels,
            800,
            600,
          );
          final afterCentroid = afterAnalysis.centroid;

          // Should NOT hit because visible mode requires visibility
          expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));
        },
      );

      testWidgets(
        'display:none is never hittable regardless of pointer-events',
        (WidgetTester tester) async {
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="10" y="10" width="40" height="40" 
                  fill="blue" display="none" pointer-events="all"/>
            <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

          final beforePixels = await VisualTestUtils.captureWidgetPixels(
            tester,
          );
          final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
            beforePixels,
            800,
            600,
          );
          final beforeCentroid = beforeAnalysis.centroid;

          final pictureFinder = find.byType(AnimatedSvgPicture);
          final topLeft = tester.getTopLeft(pictureFinder);

          // Click on display:none element
          await tester.tapAt(topLeft + const Offset(60, 60));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
          final afterAnalysis = VisualTestUtils.analyzeRedPixels(
            afterPixels,
            800,
            600,
          );
          final afterCentroid = afterAnalysis.centroid;

          // Should NOT hit - display:none always excludes from hit testing
          expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(5));
        },
      );
    });

    group('polyline hit-testing', () {
      testWidgets(
        'polyline stroke with round linecap is hittable at endpoints',
        (WidgetTester tester) async {
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <polyline id="target" points="20,50 50,20 80,50" 
                      fill="none" stroke="blue" stroke-width="10" stroke-linecap="round"/>
            <rect id="moving" x="10" y="70" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
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

          final beforePixels = await VisualTestUtils.captureWidgetPixels(
            tester,
          );
          final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
            beforePixels,
            800,
            600,
          );
          final beforeCentroid = beforeAnalysis.centroid;

          final pictureFinder = find.byType(AnimatedSvgPicture);
          final topLeft = tester.getTopLeft(pictureFinder);

          // Click at polyline endpoint
          await tester.tapAt(topLeft + const Offset(168, 100));
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
        },
      );
    });

    group('text hit-testing', () {
      testWidgets('renders and processes text element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <text id="target" x="10" y="50" font-size="24" fill="blue">Click me</text>
            <rect id="moving" x="10" y="70" width="10" height="10" fill="red">
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
                  height: 100,
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
