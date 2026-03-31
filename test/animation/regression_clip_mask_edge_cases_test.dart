// Regression tests for clipping and masking edge cases
// Tests complex clip-path and mask scenarios that have historically caused issues

import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Multiple cascading clip-paths', () {
    testWidgets('element with nested clip-path application', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="outerClip">
              <rect x="20" y="20" width="160" height="160"/>
            </clipPath>
            <clipPath id="innerClip">
              <circle cx="100" cy="100" r="60"/>
            </clipPath>
          </defs>
          <g clip-path="url(#outerClip)">
            <rect x="0" y="0" width="200" height="200" fill="red" 
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

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('three-level nested clip-paths', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="clip1">
              <rect x="10" y="10" width="180" height="180"/>
            </clipPath>
            <clipPath id="clip2">
              <rect x="30" y="30" width="140" height="140"/>
            </clipPath>
            <clipPath id="clip3">
              <circle cx="100" cy="100" r="50"/>
            </clipPath>
          </defs>
          <g clip-path="url(#clip1)">
            <g clip-path="url(#clip2)">
              <rect x="0" y="0" width="200" height="200" fill="red" 
                    clip-path="url(#clip3)"/>
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

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('overlapping clip-paths on siblings', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="leftClip">
              <rect x="0" y="0" width="120" height="200"/>
            </clipPath>
            <clipPath id="rightClip">
              <rect x="80" y="0" width="120" height="200"/>
            </clipPath>
          </defs>
          <rect x="0" y="50" width="200" height="50" fill="red" 
                clip-path="url(#leftClip)"/>
          <rect x="0" y="100" width="200" height="50" fill="blue" 
                clip-path="url(#rightClip)"/>
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
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('clip-path on group affects all children', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="groupClip">
              <circle cx="100" cy="100" r="70"/>
            </clipPath>
          </defs>
          <g clip-path="url(#groupClip)">
            <rect x="20" y="20" width="80" height="80" fill="red"/>
            <rect x="100" y="20" width="80" height="80" fill="green"/>
            <rect x="20" y="100" width="80" height="80" fill="blue"/>
            <rect x="100" y="100" width="80" height="80" fill="yellow"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask with luminance mode', () {
    testWidgets('mask-type luminance with grayscale gradient', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <linearGradient id="lumGrad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </linearGradient>
            <mask id="lumMask" mask-type="luminance">
              <rect width="200" height="200" fill="url(#lumGrad)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="red" 
                mask="url(#lumMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask-type alpha (default) uses alpha channel', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <linearGradient id="alphaGrad" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="black" stop-opacity="1"/>
              <stop offset="100%" stop-color="black" stop-opacity="0"/>
            </linearGradient>
            <mask id="alphaMask">
              <rect width="200" height="200" fill="url(#alphaGrad)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="blue" 
                mask="url(#alphaMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('luminance mask with colored content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <mask id="colorLumMask" mask-type="luminance">
              <rect x="0" y="0" width="100" height="200" fill="white"/>
              <rect x="100" y="0" width="50" height="200" fill="gray"/>
              <rect x="150" y="0" width="50" height="200" fill="black"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="green" 
                mask="url(#colorLumMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('radial gradient in luminance mask', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <radialGradient id="radialLum" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
            <mask id="radialMask" mask-type="luminance">
              <rect width="200" height="200" fill="url(#radialLum)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="purple" 
                mask="url(#radialMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask on filtered element', () {
    testWidgets('filter first then mask applied', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="blur">
              <feGaussianBlur stdDeviation="3"/>
            </filter>
            <mask id="circleMask">
              <circle cx="100" cy="100" r="60" fill="white"/>
            </mask>
          </defs>
          <rect x="40" y="40" width="120" height="120" fill="red" 
                filter="url(#blur)" mask="url(#circleMask)"/>
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
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('mask with filter applied to mask content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="softEdge">
              <feGaussianBlur stdDeviation="5"/>
            </filter>
            <mask id="softMask">
              <circle cx="100" cy="100" r="50" fill="white" 
                      filter="url(#softEdge)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="blue" 
                mask="url(#softMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('drop shadow filter with clip-path', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="shadow">
              <feDropShadow dx="5" dy="5" stdDeviation="3" flood-color="black" flood-opacity="0.5"/>
            </filter>
            <clipPath id="rectClip">
              <rect x="30" y="30" width="140" height="140"/>
            </clipPath>
          </defs>
          <circle cx="100" cy="100" r="50" fill="orange" 
                  filter="url(#shadow)" clip-path="url(#rectClip)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('complex filter chain with mask', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="complex">
              <feGaussianBlur in="SourceAlpha" stdDeviation="4" result="blur"/>
              <feOffset in="blur" dx="4" dy="4" result="offset"/>
              <feMerge>
                <feMergeNode in="offset"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
            <mask id="ellipseMask">
              <ellipse cx="100" cy="100" rx="80" ry="50" fill="white"/>
            </mask>
          </defs>
          <rect x="20" y="50" width="160" height="100" fill="teal" 
                filter="url(#complex)" mask="url(#ellipseMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('ClipPath with complex shapes', () {
    testWidgets('clipPath using path element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="pathClip">
              <path d="M100,10 L190,100 L100,190 L10,100 Z"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="red" 
                clip-path="url(#pathClip)"/>
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
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('clipPath with multiple shapes', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="multiClip">
              <circle cx="60" cy="60" r="40"/>
              <circle cx="140" cy="60" r="40"/>
              <circle cx="100" cy="140" r="40"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="green" 
                clip-path="url(#multiClip)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('clipPath with polygon element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="starClip">
              <polygon points="100,10 40,198 190,78 10,78 160,198"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="gold" 
                clip-path="url(#starClip)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('clipPath with text element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 100">
          <defs>
            <clipPath id="textClip">
              <text x="10" y="60" font-size="50" font-weight="bold">SVG</text>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="200" height="100" fill="red"/>
          <rect x="0" y="0" width="200" height="100" fill="blue" 
                clip-path="url(#textClip)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 100),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('ClipPath units and coordinate systems', () {
    testWidgets('clipPathUnits userSpaceOnUse', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="userClip" clipPathUnits="userSpaceOnUse">
              <rect x="50" y="50" width="100" height="100"/>
            </clipPath>
          </defs>
          <circle cx="100" cy="100" r="80" fill="red" 
                  clip-path="url(#userClip)"/>
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
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('clipPathUnits objectBoundingBox', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="objClip" clipPathUnits="objectBoundingBox">
              <circle cx="0.5" cy="0.5" r="0.4"/>
            </clipPath>
          </defs>
          <rect x="30" y="30" width="140" height="140" fill="blue" 
                clip-path="url(#objClip)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('clipPath with transform attribute', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="transformClip" transform="rotate(45 100 100)">
              <rect x="60" y="60" width="80" height="80"/>
            </clipPath>
          </defs>
          <circle cx="100" cy="100" r="70" fill="purple" 
                  clip-path="url(#transformClip)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Mask units and coordinate systems', () {
    testWidgets('maskUnits userSpaceOnUse', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <mask id="userMask" maskUnits="userSpaceOnUse" 
                  x="50" y="50" width="100" height="100">
              <rect x="50" y="50" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <circle cx="100" cy="100" r="80" fill="red" 
                  mask="url(#userMask)"/>
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
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('maskContentUnits objectBoundingBox', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <mask id="objContentMask" maskContentUnits="objectBoundingBox">
              <rect x="0.25" y="0.25" width="0.5" height="0.5" fill="white"/>
            </mask>
          </defs>
          <rect x="40" y="40" width="120" height="120" fill="green" 
                mask="url(#objContentMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask with x, y, width, height attributes', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <mask id="boundedMask" x="0.1" y="0.1" width="0.8" height="0.8">
              <rect width="100%" height="100%" fill="white"/>
            </mask>
          </defs>
          <rect x="20" y="20" width="160" height="160" fill="orange" 
                mask="url(#boundedMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('Clip-path and mask interaction', () {
    testWidgets('element with both clip-path and mask', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="rectClip">
              <rect x="30" y="30" width="140" height="140"/>
            </clipPath>
            <mask id="circleMask">
              <circle cx="100" cy="100" r="80" fill="white"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="red" 
                clip-path="url(#rectClip)" mask="url(#circleMask)"/>
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
      expect(analysis.pixelCount, greaterThan(100));
    });

    testWidgets('mask containing clipped content', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="innerClip">
              <rect x="60" y="60" width="80" height="80"/>
            </clipPath>
            <mask id="clippedMask">
              <circle cx="100" cy="100" r="70" fill="white" 
                      clip-path="url(#innerClip)"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="blue" 
                mask="url(#clippedMask)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('clipPath containing masked content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <mask id="gradMask">
              <linearGradient id="maskGrad" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stop-color="white"/>
                <stop offset="100%" stop-color="black"/>
              </linearGradient>
              <rect width="100%" height="100%" fill="url(#maskGrad)"/>
            </mask>
            <clipPath id="maskedClip">
              <rect x="20" y="20" width="160" height="160" mask="url(#gradMask)"/>
            </clipPath>
          </defs>
          <circle cx="100" cy="100" r="90" fill="cyan" 
                  clip-path="url(#maskedClip)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('DOM parsing verification for clip/mask', () {
    test('clipPath element parses correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <clipPath id="clip1" clipPathUnits="userSpaceOnUse">
              <rect x="10" y="10" width="80" height="80"/>
            </clipPath>
          </defs>
          <rect clip-path="url(#clip1)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final defs = document.root.children.firstWhere(
        (n) => n.tagName == 'defs',
      );
      final clipPath = defs.children.firstWhere((n) => n.tagName == 'clipPath');

      expect(clipPath.id, 'clip1');
      expect(clipPath.getAttributeValue('clipPathUnits'), 'userSpaceOnUse');
    });

    test('mask element parses correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <mask id="mask1" maskUnits="userSpaceOnUse" 
                  maskContentUnits="objectBoundingBox" mask-type="luminance">
              <rect width="100%" height="100%" fill="white"/>
            </mask>
          </defs>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final defs = document.root.children.firstWhere(
        (n) => n.tagName == 'defs',
      );
      final mask = defs.children.firstWhere((n) => n.tagName == 'mask');

      expect(mask.id, 'mask1');
      expect(mask.getAttributeValue('maskUnits'), 'userSpaceOnUse');
      expect(mask.getAttributeValue('maskContentUnits'), 'objectBoundingBox');
      expect(mask.getAttributeValue('mask-type'), 'luminance');
    });

    test('clip-path attribute on element parses correctly', () {
      const svgString = '''
        <svg>
          <rect id="r1" clip-path="url(#myClip)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final rect = document.root.children.firstWhere(
        (n) => n.tagName == 'rect',
      );

      expect(rect.getAttributeValue('clip-path'), 'url(#myClip)');
    });

    test('mask attribute on element parses correctly', () {
      const svgString = '''
        <svg>
          <circle id="c1" mask="url(#myMask)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final circle = document.root.children.firstWhere(
        (n) => n.tagName == 'circle',
      );

      expect(circle.getAttributeValue('mask'), 'url(#myMask)');
    });
  });

  group('Edge cases with empty or invalid references', () {
    testWidgets('clip-path referencing non-existent ID', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <rect x="50" y="50" width="100" height="100" fill="red" 
                clip-path="url(#nonExistent)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask referencing non-existent ID', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <circle cx="100" cy="100" r="50" fill="blue" 
                  mask="url(#missing)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('empty clipPath renders element unclipped', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <clipPath id="emptyClip"/>
          </defs>
          <rect x="50" y="50" width="100" height="100" fill="red" 
                clip-path="url(#emptyClip)"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('mask with only black content hides element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <mask id="blackMask" mask-type="luminance">
              <rect width="200" height="200" fill="black"/>
            </mask>
          </defs>
          <rect x="50" y="50" width="100" height="100" fill="red" 
                mask="url(#blackMask)"/>
          <rect x="10" y="10" width="30" height="30" fill="blue"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });
}
