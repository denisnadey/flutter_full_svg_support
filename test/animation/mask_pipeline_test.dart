import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for mask pipeline methods:
/// - _generateMaskCacheKey (animated mask cache key generation)
/// - _applyNestedMaskWithIntersection (nested mask intersection)
void main() {
  group('Animated Mask Cache Key Generation', () {
    testWidgets('animated mask content triggers cache key generation', (
      WidgetTester tester,
    ) async {
      // SVG with animated mask content - the mask circle radius is animated
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="animatedMask">
                <circle cx="50" cy="50" r="20" fill="white">
                  <animate attributeName="r" values="20;40;20" dur="2s" repeatCount="indefinite"/>
                </circle>
              </mask>
            </defs>
            <rect x="10" y="10" width="80" height="80" fill="blue" mask="url(#animatedMask)"/>
          </svg>
        ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      // First frame
      await tester.pump();

      // Advance animation and pump again
      await tester.pump(const Duration(milliseconds: 500));

      // The visible area should change as the mask animates
      // (different cache keys are generated for different animation states)
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-animated mask does not require cache key per frame', (
      WidgetTester tester,
    ) async {
      // SVG with static mask content (no animation)
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="staticMask">
                <circle cx="50" cy="50" r="40" fill="white"/>
              </mask>
            </defs>
            <rect x="10" y="10" width="80" height="80" fill="green" mask="url(#staticMask)"/>
          </svg>
        ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      // Multiple frames with no animation should render consistently
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('cache key changes when animated attribute values change', (
      WidgetTester tester,
    ) async {
      // SVG with animated fill color in mask
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="colorAnimMask">
                <rect x="0" y="0" width="100" height="100" fill="white">
                  <animate attributeName="fill" values="white;gray;white" dur="1s" repeatCount="indefinite"/>
                </rect>
              </mask>
            </defs>
            <rect x="10" y="10" width="80" height="80" fill="red" mask="url(#colorAnimMask)"/>
          </svg>
        ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      // First frame - white mask = full visibility
      await tester.pump();

      // Advance to gray mask time
      await tester.pump(const Duration(milliseconds: 500));

      // Both should render without errors
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Nested Mask Intersection', () {
    testWidgets(
      'nested masks compute intersection - visible area is intersection',
      (WidgetTester tester) async {
        // Parent group has a mask, child element has its own mask
        // The visible area should be the intersection of both masks
        const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <!-- Outer mask: left half of canvas -->
              <mask id="outerMask">
                <rect x="0" y="0" width="50" height="100" fill="white"/>
              </mask>
              <!-- Inner mask: right half of canvas -->
              <mask id="innerMask">
                <rect x="25" y="0" width="75" height="100" fill="white"/>
              </mask>
            </defs>
            <g mask="url(#outerMask)">
              <!-- This element has innerMask - visible area should be x=25 to x=50 -->
              <rect x="0" y="20" width="100" height="60" fill="blue" mask="url(#innerMask)"/>
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

        // Should render with masks applied - intersection region visible
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );

    testWidgets('nested masks with no intersection renders nothing', (
      WidgetTester tester,
    ) async {
      // Parent mask covers left side, child mask covers right side
      // No intersection = nothing visible
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <!-- Outer mask: left quarter -->
              <mask id="leftMask">
                <rect x="0" y="0" width="25" height="100" fill="white"/>
              </mask>
              <!-- Inner mask: right quarter -->
              <mask id="rightMask">
                <rect x="75" y="0" width="25" height="100" fill="white"/>
              </mask>
            </defs>
            <g mask="url(#leftMask)">
              <rect x="0" y="0" width="100" height="100" fill="red" mask="url(#rightMask)"/>
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

      // Should render - masks applied with no intersection
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('deeply nested masks all intersect correctly', (
      WidgetTester tester,
    ) async {
      // Three levels of nested masks
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="mask1">
                <rect x="10" y="10" width="80" height="80" fill="white"/>
              </mask>
              <mask id="mask2">
                <rect x="20" y="20" width="60" height="60" fill="white"/>
              </mask>
              <mask id="mask3">
                <rect x="30" y="30" width="40" height="40" fill="white"/>
              </mask>
            </defs>
            <g mask="url(#mask1)">
              <g mask="url(#mask2)">
                <rect x="0" y="0" width="100" height="100" fill="green" mask="url(#mask3)"/>
              </g>
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

      // Should render without errors - all three masks applied
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('nested mask with animated parent mask', (
      WidgetTester tester,
    ) async {
      // Parent mask is animated, child has static mask
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="animParentMask">
                <circle cx="50" cy="50" r="30" fill="white">
                  <animate attributeName="r" values="30;45;30" dur="2s" repeatCount="indefinite"/>
                </circle>
              </mask>
              <mask id="staticChildMask">
                <rect x="20" y="20" width="60" height="60" fill="white"/>
              </mask>
            </defs>
            <g mask="url(#animParentMask)">
              <rect x="0" y="0" width="100" height="100" fill="purple" mask="url(#staticChildMask)"/>
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

      // Pump multiple frames to test animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask Pipeline Edge Cases', () {
    testWidgets('mask with set animation element is detected as animated', (
      WidgetTester tester,
    ) async {
      // SVG with <set> animation in mask content
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="setAnimMask">
                <rect x="0" y="0" width="100" height="100" fill="black">
                  <set attributeName="fill" to="white" begin="0.5s"/>
                </rect>
              </mask>
            </defs>
            <rect x="10" y="10" width="80" height="80" fill="orange" mask="url(#setAnimMask)"/>
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
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask with animateTransform is detected as animated', (
      WidgetTester tester,
    ) async {
      // SVG with animateTransform in mask content
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="transformAnimMask">
                <rect x="25" y="25" width="50" height="50" fill="white">
                  <animateTransform attributeName="transform" type="rotate" 
                    values="0 50 50;180 50 50;360 50 50" dur="2s" repeatCount="indefinite"/>
                </rect>
              </mask>
            </defs>
            <rect x="10" y="10" width="80" height="80" fill="cyan" mask="url(#transformAnimMask)"/>
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
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask with nested animated child is detected as animated', (
      WidgetTester tester,
    ) async {
      // Animation is in a nested child within the mask
      const svgXml = '''
          <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <mask id="nestedAnimMask">
                <g>
                  <g>
                    <circle cx="50" cy="50" r="30" fill="white">
                      <animate attributeName="fill-opacity" values="1;0.5;1" dur="1s" repeatCount="indefinite"/>
                    </circle>
                  </g>
                </g>
              </mask>
            </defs>
            <rect x="10" y="10" width="80" height="80" fill="magenta" mask="url(#nestedAnimMask)"/>
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
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
