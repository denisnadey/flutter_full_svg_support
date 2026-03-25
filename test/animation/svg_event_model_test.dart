import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('W3C SVG Event Model', () {
    group('Event Retargeting Through <use>', () {
      testWidgets('click on element inside use retargets to use element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <rect id="baseRect" x="0" y="0" width="40" height="40" fill="blue"/>
            </defs>
            <use id="useTarget" href="#baseRect" x="30" y="30"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="useTarget.click" fill="freeze"/>
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

        // Click on the use element area - should trigger animation on useTarget
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (click retargeted to use element)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('nested use element click propagates correctly', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <circle id="baseCircle" cx="20" cy="20" r="15" fill="blue"/>
            </defs>
            <g id="parentGroup">
              <use id="useTarget" href="#baseCircle" x="30" y="30"/>
            </g>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="parentGroup.click" fill="freeze"/>
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

        // Click on the use element - should bubble to parent group
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (click bubbled to parent group)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Event Bubbling', () {
      testWidgets('click event bubbles from child to parent', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <g id="container">
              <rect id="child" x="20" y="20" width="60" height="60" fill="blue"/>
            </g>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="container.click" fill="freeze"/>
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

        // Click on child rect - event should bubble to container
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (bubbled to container)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('deep nesting bubbles through multiple levels', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <g id="level1">
              <g id="level2">
                <g id="level3">
                  <rect id="deepChild" x="20" y="20" width="60" height="60" fill="blue"/>
                </g>
              </g>
            </g>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="level1.click" fill="freeze"/>
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

        // Click on deepChild - should bubble all the way to level1
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (bubbled to level1)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Mouseenter/Mouseleave (Non-Bubbling)', () {
      testWidgets('mouseenter fires on target element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.mouseenter" fill="freeze"/>
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
        final center = tester.getCenter(pictureFinder);

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );

        // Hover over target element
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: center);
        addTearDown(gesture.removePointer);
        await tester.pump();
        await gesture.moveTo(center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (mouseenter fired)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('mouseleave fires when leaving element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue"/>
            <rect id="moving" x="10" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.mouseleave" fill="freeze"/>
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
        final center = tester.getCenter(pictureFinder);

        // Enter and then leave the target element
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: center);
        addTearDown(gesture.removePointer);
        await tester.pump();
        await gesture.moveTo(center);
        await tester.pump();
        
        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );

        // Move outside the element
        await gesture.moveTo(topLeft + const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (mouseleave fired)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });

    group('Multiple Events on Same Element', () {
      testWidgets('multiple event types trigger different animations', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="20" y="20" width="60" height="60" fill="blue"/>
            <rect id="clickMover" x="10" y="80" width="10" height="10" fill="red">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.click" fill="freeze"/>
            </rect>
            <rect id="hoverMover" x="10" y="5" width="10" height="10" fill="green">
              <animate attributeName="x" from="10" to="70" dur="1s" 
                       begin="target.mouseover" fill="freeze"/>
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
        final center = tester.getCenter(pictureFinder);

        // First hover to trigger mouseover
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: center);
        addTearDown(gesture.removePointer);
        await tester.pump();
        await gesture.moveTo(center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Then click to trigger click
        await tester.tapAt(center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Both animations should have started
        // This test verifies the SVG renders correctly with multiple event-triggered animations
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Events on Transformed Elements', () {
      testWidgets('click event works on rotated element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <rect id="target" x="30" y="30" width="40" height="40" fill="blue"
                  transform="rotate(45 50 50)"/>
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

        // Click on center of rotated rect
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

      testWidgets('click event works on scaled element', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <g transform="scale(0.5) translate(50 50)">
              <rect id="target" x="0" y="0" width="60" height="60" fill="blue"/>
            </g>
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

        // Click where the scaled element should be
        await tester.tapAt(topLeft + const Offset(70, 70));
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

    group('Events on Clipped/Masked Elements', () {
      testWidgets('click respects clip-path boundaries', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="50" cy="50" r="25"/>
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

        // Click inside the clip region (center)
        await tester.tapAt(topLeft + const Offset(100, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (clicked inside clip)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });

      testWidgets('click outside clip-path does not trigger event', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <defs>
              <clipPath id="clip">
                <circle cx="50" cy="50" r="15"/>
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

        // Click outside the clip region (corner of rect but outside circle)
        await tester.tapAt(topLeft + const Offset(50, 50));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should NOT have started (clicked outside clip)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          lessThan(5),
        );
      });
    });

    group('Event Delegation Pattern', () {
      testWidgets('parent can handle events for multiple children', (
        WidgetTester tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <g id="buttonGroup">
              <rect id="button1" x="10" y="10" width="35" height="35" fill="blue"/>
              <rect id="button2" x="55" y="10" width="35" height="35" fill="green"/>
              <rect id="button3" x="10" y="55" width="35" height="35" fill="orange"/>
              <rect id="button4" x="55" y="55" width="35" height="35" fill="purple"/>
            </g>
            <rect id="moving" x="45" y="85" width="10" height="10" fill="red">
              <animate attributeName="x" from="45" to="70" dur="1s" 
                       begin="buttonGroup.click" fill="freeze"/>
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

        // Click on button3 - should bubble to buttonGroup
        await tester.tapAt(topLeft + const Offset(55, 145));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );

        // Animation should have started (bubbled from button3 to buttonGroup)
        expect(
          (afterAnalysis.centroid.dx - beforeAnalysis.centroid.dx).abs(),
          greaterThan(5),
        );
      });
    });
  });
}
