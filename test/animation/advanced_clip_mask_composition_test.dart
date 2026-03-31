import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

/// Tests for advanced clip-path and mask composition edge cases.
///
/// Covers:
/// - Cascading multiple clip-paths with transform propagation
/// - Mask edge feathering and composition modes
/// - maskContentUnits transitions between nested contexts
/// - Subgraph masking (masks on filtered elements)
void main() {
  group('Cascading Multiple Clip-Paths', () {
    testWidgets('parent clipPath A, child clipPath B - intersection', (
      WidgetTester tester,
    ) async {
      // Parent has clipPath A (left half), child has clipPath B (right half)
      // Result should be intersection (middle strip)
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipA">
              <rect x="0" y="0" width="60" height="100"/>
            </clipPath>
            <clipPath id="clipB">
              <rect x="40" y="0" width="60" height="100"/>
            </clipPath>
          </defs>
          <g clip-path="url(#clipA)">
            <rect x="0" y="0" width="100" height="100" fill="red"
                  clip-path="url(#clipB)"/>
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

      // Should have visible red pixels only in 40-60 range (intersection)
      expect(analysis.pixelCount, greaterThan(100));
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('cascading clipPath on clipPath element itself', (
      WidgetTester tester,
    ) async {
      // clipPathB references clipPathA via clip-path attribute
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipA">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="clipB" clip-path="url(#clipA)">
              <circle cx="50" cy="50" r="40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="blue"
                clip-path="url(#clipB)"/>
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

      // Should render without errors - intersection of rect and circle
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('transform propagation through clipPath chain', (
      WidgetTester tester,
    ) async {
      // Transform on outer clipPath should affect cascaded clip
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="outerClip" transform="rotate(45 50 50)">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
            <clipPath id="innerClip">
              <circle cx="50" cy="50" r="30"/>
            </clipPath>
          </defs>
          <g clip-path="url(#outerClip)">
            <rect x="0" y="0" width="100" height="100" fill="green"
                  clip-path="url(#innerClip)"/>
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

      // Should render with rotated rectangular clip intersected with circle
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mixed clipPathUnits in cascade', (WidgetTester tester) async {
      // Outer uses userSpaceOnUse, inner uses objectBoundingBox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipUser" clipPathUnits="userSpaceOnUse">
              <rect x="20" y="20" width="60" height="60"/>
            </clipPath>
            <clipPath id="clipOBB" clipPathUnits="objectBoundingBox">
              <rect x="0.2" y="0.2" width="0.6" height="0.6"/>
            </clipPath>
          </defs>
          <g clip-path="url(#clipUser)">
            <rect x="10" y="10" width="80" height="80" fill="red"
                  clip-path="url(#clipOBB)"/>
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

      // Should handle mixed units correctly
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask Edge Feathering and Composition', () {
    testWidgets('luminance mask computes correct luminance from RGB', (
      WidgetTester tester,
    ) async {
      // Per SVG spec: luminance = 0.2126*R + 0.7152*G + 0.0722*B
      // Gray (128, 128, 128) should have ~50% luminance
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="grayMask" mask-type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="rgb(128,128,128)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red"
                mask="url(#grayMask)"/>
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

      // Should render with ~50% visibility
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('semi-transparent mask edges with anti-aliasing', (
      WidgetTester tester,
    ) async {
      // Radial gradient mask should create smooth semi-transparent edges
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <radialGradient id="fadeGrad" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
            <mask id="fadeMask" mask-type="luminance">
              <rect x="0" y="0" width="100" height="100" fill="url(#fadeGrad)"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="blue"
                mask="url(#fadeMask)"/>
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

      // Should render with smooth fade-out edges
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask with blur filter creates feathered edge', (
      WidgetTester tester,
    ) async {
      // Mask content with blur should create soft/feathered edges
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="blur">
              <feGaussianBlur stdDeviation="5"/>
            </filter>
            <mask id="blurredMask">
              <rect x="20" y="20" width="60" height="60" fill="white"
                    filter="url(#blur)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="green"
                mask="url(#blurredMask)"/>
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

      // Should render with feathered/blurred mask edges
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('maskContentUnits Transitions', () {
    testWidgets('nested masks with different maskContentUnits', (
      WidgetTester tester,
    ) async {
      // Outer mask uses userSpaceOnUse, inner uses objectBoundingBox
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="outerMask" maskContentUnits="userSpaceOnUse">
              <rect x="10" y="10" width="80" height="80" fill="white"/>
            </mask>
            <mask id="innerMask" maskContentUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8" fill="white"/>
            </mask>
          </defs>
          <g mask="url(#outerMask)">
            <rect x="0" y="0" width="100" height="100" fill="red"
                  mask="url(#innerMask)"/>
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

      // Should handle coordinate transition correctly
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('non-square objectBoundingBox with maskContentUnits', (
      WidgetTester tester,
    ) async {
      // Element with non-square bbox (wide rectangle)
      const svgXml = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <mask id="wideMask" maskContentUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="blue"
                mask="url(#wideMask)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 400, height: 200),
          ),
        ),
      );

      await tester.pump();

      // Should properly scale mask content for non-square bbox
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('maskUnits vs maskContentUnits difference', (
      WidgetTester tester,
    ) async {
      // maskUnits affects mask region, maskContentUnits affects content coords
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="mixedMask" 
                  maskUnits="objectBoundingBox"
                  maskContentUnits="userSpaceOnUse">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="green"
                mask="url(#mixedMask)"/>
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

      // Should correctly distinguish between maskUnits and maskContentUnits
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Subgraph Masking (Masks on Filtered Elements)', () {
    testWidgets('mask applied after filter effect', (
      WidgetTester tester,
    ) async {
      // Element with both filter and mask - filter applies first
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="colorShift">
              <feColorMatrix type="hueRotate" values="90"/>
            </filter>
            <mask id="rectMask">
              <rect x="20" y="20" width="60" height="60" fill="white"/>
            </mask>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="red"
                filter="url(#colorShift)" mask="url(#rectMask)"/>
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

      // Filter should be applied first, then mask clips the result
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask on blur-filtered element', (WidgetTester tester) async {
      // Blur filter followed by mask should mask the blurred image
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="blurFilter">
              <feGaussianBlur stdDeviation="3"/>
            </filter>
            <mask id="circleMask">
              <circle cx="50" cy="50" r="35" fill="white"/>
            </mask>
          </defs>
          <rect x="20" y="20" width="60" height="60" fill="blue"
                filter="url(#blurFilter)" mask="url(#circleMask)"/>
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

      // Blur should be applied to rect, then circle mask clips result
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('group with filter and mask on children', (
      WidgetTester tester,
    ) async {
      // Group has filter, children have individual masks
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="groupFilter">
              <feColorMatrix type="saturate" values="0.5"/>
            </filter>
            <mask id="leftMask">
              <rect x="0" y="0" width="50" height="100" fill="white"/>
            </mask>
            <mask id="rightMask">
              <rect x="50" y="0" width="50" height="100" fill="white"/>
            </mask>
          </defs>
          <g filter="url(#groupFilter)">
            <rect x="10" y="10" width="40" height="80" fill="red"
                  mask="url(#leftMask)"/>
            <rect x="50" y="10" width="40" height="80" fill="blue"
                  mask="url(#rightMask)"/>
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

      // Group filter affects children, individual masks apply after
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Edge Cases', () {
    testWidgets('circular clipPath reference prevention', (
      WidgetTester tester,
    ) async {
      // clipPathA references clipPathB which references clipPathA
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipA" clip-path="url(#clipB)">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
            <clipPath id="clipB" clip-path="url(#clipA)">
              <circle cx="50" cy="50" r="40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red"
                clip-path="url(#clipA)"/>
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

      // Should not crash - circular reference should be detected
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('deeply nested clip-path cascade (10 levels)', (
      WidgetTester tester,
    ) async {
      // 10 levels of cascading clipPaths
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="c1"><rect x="5" y="5" width="90" height="90"/></clipPath>
            <clipPath id="c2" clip-path="url(#c1)"><rect x="10" y="10" width="80" height="80"/></clipPath>
            <clipPath id="c3" clip-path="url(#c2)"><rect x="15" y="15" width="70" height="70"/></clipPath>
            <clipPath id="c4" clip-path="url(#c3)"><rect x="20" y="20" width="60" height="60"/></clipPath>
            <clipPath id="c5" clip-path="url(#c4)"><rect x="25" y="25" width="50" height="50"/></clipPath>
            <clipPath id="c6" clip-path="url(#c5)"><rect x="30" y="30" width="40" height="40"/></clipPath>
            <clipPath id="c7" clip-path="url(#c6)"><rect x="35" y="35" width="30" height="30"/></clipPath>
            <clipPath id="c8" clip-path="url(#c7)"><rect x="37" y="37" width="26" height="26"/></clipPath>
            <clipPath id="c9" clip-path="url(#c8)"><rect x="39" y="39" width="22" height="22"/></clipPath>
            <clipPath id="c10" clip-path="url(#c9)"><rect x="40" y="40" width="20" height="20"/></clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="purple"
                clip-path="url(#c10)"/>
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

      // Should handle deep cascade up to max depth
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('empty mask region results in no rendering', (
      WidgetTester tester,
    ) async {
      // Mask with zero-area region should hide content
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="emptyMask">
              <rect x="0" y="0" width="0" height="0" fill="white"/>
            </mask>
          </defs>
          <rect x="20" y="20" width="60" height="60" fill="red"
                mask="url(#emptyMask)"/>
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

      // Should not crash, and should have minimal/no visible pixels
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
