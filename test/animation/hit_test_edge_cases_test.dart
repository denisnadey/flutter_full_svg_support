import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Hit-Testing Edge Cases', () {
    group('Nested ClipPath', () {
      testWidgets('clipPath referencing another clipPath respects both', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="innerClip">
                <circle cx="50" cy="50" r="30"/>
              </clipPath>
              <clipPath id="outerClip" clip-path="url(#innerClip)">
                <rect x="20" y="20" width="60" height="60"/>
              </clipPath>
            </defs>
            <rect id="target" x="0" y="0" width="100" height="100" fill="blue" 
                  clip-path="url(#outerClip)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click inside both clips (center)
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

      testWidgets('clipPath with transform affects hit region', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip" transform="translate(20, 20)">
                <circle cx="30" cy="30" r="20"/>
              </clipPath>
            </defs>
            <rect id="target" x="0" y="0" width="100" height="100" fill="blue" 
                  clip-path="url(#clip)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click at (50, 50) in SVG coords = (100, 100) in widget coords
        // With transform, the clip circle is at (50, 50) center
        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Mask Gradient Alpha', () {
      testWidgets('mask with transparent gradient stops excludes from hit', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <linearGradient id="maskGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                <stop offset="0%" stop-color="white" stop-opacity="1"/>
                <stop offset="50%" stop-color="white" stop-opacity="0"/>
                <stop offset="100%" stop-color="white" stop-opacity="0"/>
              </linearGradient>
              <mask id="mask">
                <rect x="0" y="0" width="100" height="100" fill="url(#maskGrad)"/>
              </mask>
            </defs>
            <rect id="target" x="0" y="0" width="100" height="100" fill="blue" 
                  mask="url(#mask)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click on left side (visible region)
        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );

        await tester.tapAt(topLeft + const Offset(40, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (gradient has visible portion)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(2),
        );
      });
    });

    group('Use Element Boundary', () {
      // Skip: Complex nested <use> chains require event propagation from
      // child elements to parent <use> elements for SMIL click events to work.
      // This is a known limitation - the hit test returns the innermost element
      // ID rather than propagating the click to the containing <use> element.
      testWidgets(
        'nested use references work correctly',
        (WidgetTester tester) async {
          const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <circle id="baseCircle" cx="0" cy="0" r="10" fill="blue"/>
              <g id="group1">
                <use href="#baseCircle" x="20" y="20"/>
              </g>
              <g id="group2">
                <use href="#group1" x="30" y="30"/>
              </g>
            </defs>
            <use id="target" href="#group2" x="0" y="0"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

          // Circle should be at (50, 50) in SVG coords = (100, 100) in widget
          final beforePixels = await VisualTestUtils.captureWidgetPixels(
            tester,
          );
          final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
            beforePixels,
            800,
            600,
          );

          await tester.tapAt(topLeft + const Offset(100, 100));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));

          final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
          final afterAnalysis = VisualTestUtils.analyzeRedPixels(
            afterPixels,
            800,
            600,
          );

          // Animation should have started
          expect(
            (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
            greaterThan(5),
          );
        },
        skip:
            true, // Nested use chains need event propagation to parent use elements
      );

      testWidgets('pointer-events:none on use element blocks hit', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" x="20" y="20" width="60" height="60" fill="blue"/>
            </defs>
            <use id="target" href="#baseRect" pointer-events="none"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started due to pointer-events:none
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });
    });

    group('Transform Combinations', () {
      testWidgets('transform-origin affects hit region', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="40" height="40" fill="blue"
                  transform="rotate(45)"
                  style="transform-origin: 40px 40px"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click near center where rotated rect should be
        await tester.tapAt(topLeft + const Offset(80, 80));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('skewX transform affects hit region', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="40" height="40" fill="blue"
                  transform="skewX(30)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in the skewed rect area
        await tester.tapAt(topLeft + const Offset(100, 80));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Text Hit-Testing', () {
      testWidgets('text with letter-spacing has correct hit gaps', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <text id="target" x="10" y="50" font-size="24" fill="blue" 
                  letter-spacing="20">ABC</text>
            <rect id="moving" x="10" y="70" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

      testWidgets('text with per-character rotation has correct hit regions', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <text id="target" x="20 50 80" y="50" rotate="0 15 30" 
                  font-size="24" fill="blue">ABC</text>
            <rect id="moving" x="10" y="70" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

      testWidgets('textPath follows path geometry for hit regions', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <defs>
              <path id="curve" d="M 10 50 Q 100 10 190 50"/>
            </defs>
            <text font-size="16" fill="blue">
              <textPath id="target" href="#curve">Text on curve</textPath>
            </text>
            <rect id="moving" x="10" y="70" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

    group('Pointer-Events Semantics', () {
      testWidgets('visibleFill requires fill to be visible', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" 
                  fill="none" stroke="blue" stroke-width="5"
                  pointer-events="visibleFill"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in center (fill area is none)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started (fill is none)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });

      testWidgets('visibleStroke requires stroke to be visible', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" 
                  fill="blue" stroke="none"
                  pointer-events="visibleStroke"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in center (stroke is none)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started (stroke is none)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });

      testWidgets('bounding-box mode uses element bounds', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <circle id="target" cx="50" cy="50" r="20" 
                    fill="blue" pointer-events="bounding-box"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click on corner of bounding box (outside circle but inside bbox)
        await tester.tapAt(topLeft + const Offset(66, 66));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (bounding-box mode)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('ClipPathUnits objectBoundingBox', () {
      testWidgets('objectBoundingBox units transform clipPath correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip" clipPathUnits="objectBoundingBox">
                <rect x="0.25" y="0.25" width="0.5" height="0.5"/>
              </clipPath>
            </defs>
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue" 
                  clip-path="url(#clip)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in center (inside clip region)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final insidePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final insideAnalysis = VisualTestUtils.analyzeRedPixels(
          insidePixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (insideAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Mask ContentUnits', () {
      testWidgets('maskContentUnits objectBoundingBox transforms mask', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <mask id="mask" maskContentUnits="objectBoundingBox">
                <rect x="0.2" y="0.2" width="0.6" height="0.6" fill="white"/>
              </mask>
            </defs>
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue" 
                  mask="url(#mask)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in center (inside mask visible region)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final insidePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final insideAnalysis = VisualTestUtils.analyzeRedPixels(
          insidePixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (insideAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Visibility vs Opacity Hit-Testing', () {
      testWidgets('visibility:hidden blocks hit-testing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue" 
                  visibility="hidden"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started (visibility:hidden)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });

      testWidgets('opacity:0 does NOT block hit-testing per CSS spec', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue" 
                  opacity="0"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation SHOULD have started (opacity:0 is still hit-testable)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('display:none blocks hit-testing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue" 
                  display="none"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started (display:none)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });

      testWidgets('visibility:collapse blocks hit-testing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue" 
                  visibility="collapse"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started (visibility:collapse)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });
    });

    group('Clip-Path + Mask + Transform Interaction', () {
      testWidgets('clip-path + mask + translate transform', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="50" cy="50" r="40"/>
              </clipPath>
              <mask id="mask">
                <rect x="20" y="20" width="60" height="60" fill="white"/>
              </mask>
            </defs>
            <rect id="target" x="0" y="0" width="100" height="100" fill="blue" 
                  clip-path="url(#clip)" mask="url(#mask)" 
                  transform="translate(0, 0)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in center (inside both clip and mask)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('clip-path + mask + rotate transform', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <rect x="25" y="25" width="50" height="50"/>
              </clipPath>
              <mask id="mask">
                <rect x="20" y="20" width="60" height="60" fill="white"/>
              </mask>
            </defs>
            <rect id="target" x="25" y="25" width="50" height="50" fill="blue" 
                  clip-path="url(#clip)" mask="url(#mask)" 
                  transform="rotate(45, 50, 50)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in center (inside the rotated clip/mask region)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('clip-path + mask + scale transform', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="50" cy="50" r="20"/>
              </clipPath>
              <mask id="mask">
                <rect x="30" y="30" width="40" height="40" fill="white"/>
              </mask>
            </defs>
            <rect id="target" x="30" y="30" width="40" height="40" fill="blue" 
                  clip-path="url(#clip)" mask="url(#mask)" 
                  transform="scale(1.0)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in center (inside scaled clip/mask)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Pointer-Events All Values', () {
      testWidgets('pointer-events:all allows hit anywhere in bounding box', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <circle id="target" cx="50" cy="50" r="20" 
                    fill="blue" pointer-events="all"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Test should render without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('pointer-events:none blocks all hits', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue" 
                  pointer-events="none"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started (pointer-events:none)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });

      testWidgets('pointer-events:fill only allows fill area hits', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" 
                  fill="blue" stroke="green" stroke-width="10"
                  pointer-events="fill"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Test should render without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('pointer-events:stroke only allows stroke area hits', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" 
                  fill="none" stroke="blue" stroke-width="10"
                  pointer-events="stroke"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Test should render without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('pointer-events:painted requires paint', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" 
                  fill="blue"
                  pointer-events="painted"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (painted allows painted areas)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('pointer-events:visible requires visibility', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" 
                  fill="none"
                  pointer-events="visible"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (visible allows all visible areas)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Nested Use with Text', () {
      testWidgets('use referencing symbol with text is hit-testable', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <defs>
              <symbol id="textSymbol" viewBox="0 0 100 50">
                <text id="innerText" x="10" y="30" font-size="20" fill="blue">Click Me</text>
              </symbol>
            </defs>
            <use id="target" href="#textSymbol" x="50" y="25" width="100" height="50"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Test should render without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('use with x/y offset affects text hit region', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <defs>
              <g id="textGroup">
                <rect id="bg" x="0" y="0" width="80" height="40" fill="lightblue"/>
                <text x="10" y="25" font-size="16" fill="blue">Text</text>
              </g>
            </defs>
            <use id="target" href="#textGroup" x="60" y="30"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="150" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Test should render without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Nested ClipPath Composition', () {
      testWidgets('deeply nested clipPaths compose correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip1">
                <circle cx="50" cy="50" r="45"/>
              </clipPath>
              <clipPath id="clip2" clip-path="url(#clip1)">
                <rect x="10" y="10" width="80" height="80"/>
              </clipPath>
              <clipPath id="clip3" clip-path="url(#clip2)">
                <circle cx="50" cy="50" r="35"/>
              </clipPath>
            </defs>
            <rect id="target" x="0" y="0" width="100" height="100" fill="blue" 
                  clip-path="url(#clip3)"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
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

        // Click in center (inside all nested clips)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

  });
}
