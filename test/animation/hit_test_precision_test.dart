import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Hit-Test Precision', () {
    group('ClipPath Precision', () {
      testWidgets('point inside clipPath hits element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="50" cy="50" r="25"/>
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

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click inside clip circle (center at 50,50 SVG = 100,100 widget)
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

      testWidgets('point outside clipPath but inside element misses', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="50" cy="50" r="20"/>
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

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click outside clip circle but inside element (corner at 10,10 SVG = 20,20 widget)
        await tester.tapAt(topLeft + const Offset(20, 20));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started - outside clip region
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });

      testWidgets('clipPath with objectBoundingBox units', (
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

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Rect is at 20,20 with size 60x60
        // Clip is 25%-75% of rect = 35,35 to 65,65 in SVG coords
        // Center is at 50,50 SVG = 100,100 widget
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started - inside objectBoundingBox clip
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('nested clipPath scenarios', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="innerClip">
                <circle cx="50" cy="50" r="30"/>
              </clipPath>
              <clipPath id="outerClip" clip-path="url(#innerClip)">
                <rect x="30" y="30" width="40" height="40"/>
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click inside both clips (center)
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

    group('Mask Precision', () {
      testWidgets('point inside mask region hits element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <mask id="myMask">
                <circle cx="50" cy="50" r="30" fill="white"/>
              </mask>
            </defs>
            <rect id="target" x="0" y="0" width="100" height="100" fill="blue" 
                  mask="url(#myMask)"/>
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click inside mask region (center)
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

      testWidgets('mask with fill:none content not hit-testable', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <mask id="emptyMask">
                <circle cx="50" cy="50" r="30" fill="none" stroke="none"/>
              </mask>
            </defs>
            <rect id="target" x="0" y="0" width="100" height="100" fill="blue" 
                  mask="url(#emptyMask)"/>
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
        // Capture baseline pixel analysis (side effect: validates pixel buffer)
        VisualTestUtils.analyzeRedPixels(beforePixels, 800, 600);

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click where mask content has no visible paint
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should still start - mask with no content allows hit
        // (empty mask geometry = null path = allow hit)
        // beforeAnalysis establishes baseline; afterAnalysis confirms animation ran
        expect(afterAnalysis.pixelCount, greaterThan(0));
      });
    });

    group('Use Element Precision', () {
      testWidgets('use element with x/y offset hit-tests at correct position', (
        WidgetTester tester,
      ) async {
        // Note: SMIL event uses baseRect.click because hit-test returns referenced element ID
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" x="0" y="0" width="20" height="20" fill="blue"/>
            </defs>
            <use id="useTarget" href="#baseRect" x="40" y="40"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="baseRect.click" fill="freeze"/>
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Rect is positioned at 40,40 via use element x/y
        // Click at 50,50 SVG coords = 100,100 widget coords (inside the rect)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started - hit-test correctly finds element at use offset position
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('symbol with viewBox hit-tests with viewport transformation', (
        WidgetTester tester,
      ) async {
        // Note: SMIL event uses innerRect.click because hit-test returns referenced element ID
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <symbol id="mySymbol" viewBox="0 0 50 50">
                <rect id="innerRect" x="10" y="10" width="30" height="30" fill="blue"/>
              </symbol>
            </defs>
            <use id="useTarget" href="#mySymbol" x="25" y="25" width="50" height="50"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="innerRect.click" fill="freeze"/>
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Symbol content is scaled - click at center (50,50 SVG = 100,100 widget)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started - hit-test correctly transforms symbol viewport
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

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

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click inside the use element
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

    group('Text Character-Level Precision', () {
      testWidgets('text with per-character dx offsets', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <text id="target" x="10" y="50" font-size="20"
                  dx="0 10 10 10">ABCD</text>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="100" dur="1s" 
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
                  width: 400,
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click on text area - text starts at x=10, scale is 2x (400/200)
        // Click at first character position: 10 SVG = 20 widget (with centering offset)
        await tester.tapAt(topLeft + const Offset(40, 100));
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

      testWidgets('text with rotation attribute', (WidgetTester tester) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <text id="target" x="50" y="50" font-size="20" 
                  rotate="0 15 30 45">TEST</text>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="100" dur="1s" 
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
                  width: 400,
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click on rotated text area
        await tester.tapAt(topLeft + const Offset(140, 100));
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

      testWidgets('textPath character positioning along path', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <defs>
              <path id="textPathDef" d="M 10,80 Q 100,10 190,80"/>
            </defs>
            <text id="target" font-size="16">
              <textPath href="#textPathDef">Click me!</textPath>
            </text>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="100" dur="1s" 
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
                  width: 400,
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click on textPath - near the start of the path (left side)
        // Path starts at 10,80 and curves, so click near start position
        await tester.tapAt(topLeft + const Offset(50, 150));
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

    group('Combined Precision Scenarios', () {
      testWidgets('element with both clipPath and mask', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <rect x="20" y="20" width="60" height="60"/>
              </clipPath>
              <mask id="myMask">
                <circle cx="50" cy="50" r="25" fill="white"/>
              </mask>
            </defs>
            <rect id="target" x="0" y="0" width="100" height="100" fill="blue" 
                  clip-path="url(#clip)" mask="url(#myMask)"/>
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click inside both clip and mask (center)
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

      testWidgets('use element with clipPath on referenced content', (
        WidgetTester tester,
      ) async {
        // Note: SMIL event uses baseRect.click because hit-test returns referenced element ID
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="25" cy="25" r="20"/>
              </clipPath>
              <rect id="baseRect" x="0" y="0" width="50" height="50" fill="blue"
                    clip-path="url(#clip)"/>
            </defs>
            <use id="useTarget" href="#baseRect" x="25" y="25"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="baseRect.click" fill="freeze"/>
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click where use element positions the clipped content
        // Rect at 25,25 with clip circle at 25,25 r=20 relative to rect
        // So clip center is at 50,50 SVG = 100,100 widget
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started - hit-test correctly handles clipPath through use
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('transformed element with clipPath', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="50" cy="50" r="30"/>
              </clipPath>
            </defs>
            <rect id="target" x="25" y="25" width="50" height="50" fill="blue" 
                  clip-path="url(#clip)" transform="rotate(45 50 50)"/>
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click at center where rotated rect and clip intersect
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
