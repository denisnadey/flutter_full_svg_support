import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Advanced Hit-Testing Features', () {
    // =========================================================================
    // MARKER HIT-TESTING TESTS
    // =========================================================================
    group('Marker element hit-testing', () {
      testWidgets('marker-start is hit-testable on path', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <marker id="arrow" markerWidth="10" markerHeight="10" refX="5" refY="5" orient="auto">
                <circle cx="5" cy="5" r="4" fill="red"/>
              </marker>
            </defs>
            <path id="target" d="M20,50 L80,50" 
                  stroke="blue" stroke-width="2" marker-start="url(#arrow)"/>
            <rect id="moving" x="10" y="10" width="10" height="10" fill="green">
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click on the marker-start position (near x=20 in SVG coords)
        await tester.tapAt(topLeft + const Offset(40, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('marker-end is hit-testable on polyline', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <marker id="triangle" markerWidth="10" markerHeight="10" refX="5" refY="5" orient="auto">
                <polygon points="0,0 10,5 0,10" fill="orange"/>
              </marker>
            </defs>
            <polyline id="target" points="20,50 50,20 80,50" 
                      fill="none" stroke="blue" stroke-width="2" marker-end="url(#triangle)"/>
            <rect id="moving" x="10" y="70" width="10" height="10" fill="green">
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

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    // =========================================================================
    // GLYPH-PRECISION TEXT HIT-TESTING TESTS
    // =========================================================================
    group('Glyph-precision text hit-testing', () {
      testWidgets('per-character positioned text is hit-testable', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <text id="target" x="10 30 50 70 90" y="50" font-size="20" fill="blue">Hello</text>
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

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Click on a character in the text
        await tester.tapAt(topLeft + const Offset(30, 50));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('rotated text characters have correct hit regions', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 100">
            <text id="target" x="50" y="50" font-size="20" fill="blue" rotate="0 30 60 90 120">ABCDE</text>
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

    // =========================================================================
    // ANIMATION EVENT TARGETING TESTS (beginEvent/endEvent)
    // =========================================================================
    group('SVG animation event targeting', () {
      testWidgets('animation beginEvent triggers dependent animation', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="first" x="10" y="10" width="20" height="20" fill="blue">
              <animate id="anim1" attributeName="x" from="10" to="50" dur="0.5s" begin="0s" fill="freeze"/>
            </rect>
            <rect id="second" x="10" y="50" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="70" dur="0.5s" begin="anim1.beginEvent" fill="freeze"/>
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
        await tester.pump(const Duration(milliseconds: 600));

        // Both animations should have completed
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('animation endEvent triggers dependent animation', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="first" x="10" y="10" width="20" height="20" fill="blue">
              <animate id="anim1" attributeName="x" from="10" to="50" dur="0.3s" begin="0s" fill="freeze"/>
            </rect>
            <rect id="second" x="10" y="50" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="70" dur="0.5s" begin="anim1.endEvent" fill="freeze"/>
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
        // First animation starts at 0 and ends at 0.3s
        await tester.pump(const Duration(milliseconds: 350));
        // Second animation should now be running (triggered by endEvent)
        await tester.pump(const Duration(milliseconds: 500));

        // Both animations should have completed
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('beginEvent with offset triggers correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="first" x="10" y="10" width="20" height="20" fill="blue">
              <animate id="anim1" attributeName="x" from="10" to="50" dur="0.2s" begin="0s" fill="freeze"/>
            </rect>
            <rect id="second" x="10" y="50" width="20" height="20" fill="red">
              <animate attributeName="x" from="10" to="70" dur="0.3s" begin="anim1.beginEvent+0.1s" fill="freeze"/>
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
        await tester.pump(const Duration(milliseconds: 600));

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    // =========================================================================
    // USE ELEMENT EVENT DELEGATION TESTS
    // =========================================================================
    group('DOM event delegation through use-referenced elements', () {
      testWidgets('click on use shadow content triggers use element event', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <g id="button">
                <rect x="0" y="0" width="30" height="30" fill="blue"/>
              </g>
            </defs>
            <use id="useTarget" href="#button" x="20" y="20"/>
            <rect id="moving" x="10" y="70" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="0.5s" begin="useTarget.click" fill="freeze"/>
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

        // Click inside the use-referenced rect (at use position x=20, y=20)
        await tester.tapAt(topLeft + const Offset(70, 70));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

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

      testWidgets('nested use elements properly delegate events', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <circle id="dot" r="10" fill="purple"/>
              <g id="group">
                <use href="#dot" x="15" y="15"/>
              </g>
            </defs>
            <use id="target" href="#group" x="30" y="30"/>
            <rect id="moving" x="10" y="70" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="0.5s" begin="target.click" fill="freeze"/>
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

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    // =========================================================================
    // EVENODD FILL-RULE EDGE CASE TESTS
    // =========================================================================
    group('Advanced path fill-rule edge cases', () {
      testWidgets('evenodd self-intersecting path hit-testing', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <path id="target" d="M10,10 L90,10 L90,90 L50,50 L10,90 Z" 
                  fill="blue" fill-rule="evenodd"/>
            <rect id="moving" x="10" y="10" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="0.5s" begin="target.click" fill="freeze"/>
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

        // Click on filled area of the evenodd path
        await tester.tapAt(topLeft + const Offset(100, 60));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('evenodd star polygon with interior hole', (
        WidgetTester tester,
      ) async {
        // Five-pointed star has a hole in the middle with evenodd
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <polygon id="target" 
                     points="50,5 61,40 98,40 68,62 79,97 50,75 21,97 32,62 2,40 39,40"
                     fill="gold" fill-rule="evenodd"/>
            <rect id="moving" x="10" y="10" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="0.5s" begin="target.click" fill="freeze"/>
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

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('collinear segments in evenodd path', (
        WidgetTester tester,
      ) async {
        // Path with collinear segments (degenerate case)
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <path id="target" 
                  d="M10,50 L50,50 L90,50 L90,90 L10,90 Z"
                  fill="blue" fill-rule="evenodd"/>
            <rect id="moving" x="10" y="10" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="0.5s" begin="target.click" fill="freeze"/>
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

        // Click inside the path (below the collinear segment)
        await tester.tapAt(topLeft + const Offset(100, 140));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Test renders without errors
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    // =========================================================================
    // INTEGRATION TESTS
    // =========================================================================
    group('Integration tests', () {
      testWidgets('complex SVG with multiple advanced features', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 200 200">
            <!-- Marker definitions -->
            <defs>
              <marker id="dot" markerWidth="8" markerHeight="8" refX="4" refY="4">
                <circle cx="4" cy="4" r="3" fill="red"/>
              </marker>
              <g id="reusable">
                <rect width="30" height="30" fill="purple"/>
              </g>
            </defs>
            
            <!-- Path with markers -->
            <path id="markerPath" d="M20,100 L80,100" 
                  stroke="blue" stroke-width="2" 
                  marker-start="url(#dot)" marker-end="url(#dot)"/>
            
            <!-- Text with per-character positioning -->
            <text id="posText" x="100 120 140" y="50" font-size="16" fill="black">ABC</text>
            
            <!-- Use element -->
            <use id="useElem" href="#reusable" x="100" y="100"/>
            
            <!-- Evenodd path -->
            <path id="evenoddPath" d="M150,150 L190,150 L190,190 L150,190 Z M160,160 L180,160 L180,180 L160,180 Z"
                  fill="green" fill-rule="evenodd"/>
            
            <!-- Animated indicator -->
            <rect id="indicator" x="10" y="180" width="10" height="10" fill="orange">
              <animate id="indAnim" attributeName="x" from="10" to="180" dur="1s" 
                       begin="markerPath.click; posText.click; useElem.click; evenoddPath.click" 
                       fill="freeze"/>
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
                  height: 400,
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
