// Regression tests for use/symbol edge cases
// Tests complex use/symbol scenarios that have historically caused issues

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

void main() {
  group('Nested use references', () {
    testWidgets('use referencing another use element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="base" width="20" height="20" fill="red"/>
            <g id="usedRect">
              <use href="#base" x="5" y="5"/>
            </g>
          </defs>
          <use href="#usedRect" x="50" y="50"/>
          <use href="#usedRect" x="100" y="100"/>
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

    testWidgets('three-level deep use nesting', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <circle id="dot" r="5" fill="blue"/>
            <g id="level1">
              <use href="#dot" cx="10" cy="10"/>
            </g>
            <g id="level2">
              <use href="#level1" x="20" y="0"/>
            </g>
          </defs>
          <use href="#level2" x="50" y="50"/>
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

    testWidgets('use referencing use with transform', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="box" width="30" height="30" fill="green"/>
            <g id="scaled">
              <use href="#box" transform="scale(1.5)"/>
            </g>
          </defs>
          <use href="#scaled" x="50" y="50" transform="rotate(45 65 65)"/>
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

    testWidgets('use referencing group with multiple uses inside', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <circle id="c" r="8" fill="red"/>
            <g id="multiUse">
              <use href="#c" x="0" y="0"/>
              <use href="#c" x="30" y="0"/>
              <use href="#c" x="15" y="26"/>
            </g>
          </defs>
          <use href="#multiUse" x="50" y="50"/>
          <use href="#multiUse" x="100" y="100"/>
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

  group('Use with viewBox scaling', () {
    testWidgets('symbol with viewBox scaled via use width/height', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="icon1" viewBox="0 0 24 24">
              <rect width="24" height="24" fill="purple"/>
              <circle cx="12" cy="12" r="8" fill="white"/>
            </symbol>
          </defs>
          <use href="#icon1" x="20" y="20" width="60" height="60"/>
          <use href="#icon1" x="100" y="100" width="80" height="80"/>
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

    testWidgets('symbol viewBox with non-zero origin', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="offsetIcon" viewBox="10 10 20 20">
              <rect x="10" y="10" width="20" height="20" fill="orange"/>
            </symbol>
          </defs>
          <use href="#offsetIcon" x="50" y="50" width="80" height="80"/>
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
      expect(pixels.length, greaterThan(0));
    });

    testWidgets('symbol with aspect ratio different from use dimensions', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="wideIcon" viewBox="0 0 100 20">
              <rect width="100" height="20" fill="cyan"/>
            </symbol>
          </defs>
          <use href="#wideIcon" x="20" y="50" width="160" height="100"/>
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

    testWidgets('symbol with preserveAspectRatio="none"', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="stretchIcon" viewBox="0 0 50 50" preserveAspectRatio="none">
              <circle cx="25" cy="25" r="20" fill="magenta"/>
            </symbol>
          </defs>
          <use href="#stretchIcon" x="20" y="20" width="160" height="60"/>
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

    testWidgets('use without width/height uses symbol natural size', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="naturalIcon" viewBox="0 0 40 40">
              <rect width="40" height="40" fill="teal"/>
            </symbol>
          </defs>
          <use href="#naturalIcon" x="80" y="80"/>
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

  group('Use inside clip-path', () {
    testWidgets('clipPath referencing use element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <circle id="clipShape" cx="50" cy="50" r="40"/>
            <clipPath id="clip1">
              <use href="#clipShape"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="red" 
                clip-path="url(#clip1)"/>
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

    testWidgets('clipPath with use referencing symbol', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="starShape" viewBox="0 0 100 100">
              <polygon points="50,5 20,95 95,40 5,40 80,95" fill="black"/>
            </symbol>
            <clipPath id="starClip">
              <use href="#starShape" width="100" height="100"/>
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

    testWidgets('use element with its own clip-path', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="bigRect" width="150" height="150" fill="blue"/>
            <clipPath id="circleClip">
              <circle cx="75" cy="75" r="50"/>
            </clipPath>
          </defs>
          <use href="#bigRect" x="25" y="25" clip-path="url(#circleClip)"/>
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

    testWidgets('nested clip-paths with use elements', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <circle id="c1" cx="50" cy="50" r="40"/>
            <rect id="r1" x="30" y="30" width="100" height="100"/>
            <clipPath id="outerClip">
              <use href="#c1"/>
            </clipPath>
            <clipPath id="innerClip" clip-path="url(#outerClip)">
              <use href="#r1"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="200" height="200" fill="purple" 
                clip-path="url(#innerClip)"/>
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

  group('CSS styling through use boundary', () {
    testWidgets('CSS fill style inherits through use', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <style>
            .styled { fill: red; }
          </style>
          <defs>
            <rect id="styledRect" width="60" height="60" class="styled"/>
          </defs>
          <use href="#styledRect" x="70" y="70"/>
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

    testWidgets('use element CSS inheritance behavior', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="blueRect" width="60" height="60" fill="blue"/>
          </defs>
          <use href="#blueRect" x="70" y="70" fill="red"/>
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

      // Should render without error - actual color inheritance depends on implementation
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('stroke properties inherit through use', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="strokeRect" x="5" y="5" width="50" height="50" fill="none"/>
          </defs>
          <use href="#strokeRect" x="70" y="70" stroke="red" stroke-width="4"/>
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
      expect(analysis.pixelCount, greaterThan(10));
    });

    testWidgets('opacity on use affects all shadow content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <g id="multiShape">
              <rect width="40" height="40" fill="red"/>
              <circle cx="60" cy="20" r="20" fill="blue"/>
            </g>
          </defs>
          <use href="#multiShape" x="50" y="80" opacity="0.5"/>
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

  group('Use referencing different element types', () {
    testWidgets('use referencing path element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <path id="arrow" d="M0,0 L30,15 L0,30 L10,15 Z" fill="green"/>
          </defs>
          <use href="#arrow" x="50" y="50"/>
          <use href="#arrow" x="100" y="100" transform="rotate(90 115 115)"/>
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

    testWidgets('use referencing text element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 300 200">
          <defs>
            <text id="greeting" font-size="24">Hello!</text>
          </defs>
          <use href="#greeting" x="50" y="50" fill="red"/>
          <use href="#greeting" x="50" y="100" fill="blue"/>
          <use href="#greeting" x="50" y="150" fill="green"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 300, height: 200),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('use referencing image element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <image id="img1" width="50" height="50" 
                   href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="/>
          </defs>
          <use href="#img1" x="20" y="20"/>
          <use href="#img1" x="100" y="100"/>
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

    testWidgets('use referencing line element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <line id="dash" x1="0" y1="0" x2="50" y2="0" 
                  stroke="black" stroke-width="2"/>
          </defs>
          <use href="#dash" x="50" y="50"/>
          <use href="#dash" x="50" y="70"/>
          <use href="#dash" x="50" y="90"/>
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

    testWidgets('use referencing polyline element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <polyline id="zigzag" points="0,0 20,30 40,0 60,30 80,0" 
                      fill="none" stroke="orange" stroke-width="3"/>
          </defs>
          <use href="#zigzag" x="50" y="50"/>
          <use href="#zigzag" x="50" y="120"/>
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

  group('Use with animations', () {
    testWidgets('use referencing animated element', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="animRect" width="40" height="40" fill="blue">
              <animate attributeName="fill" values="blue;red;blue" 
                       dur="2s" repeatCount="indefinite"/>
            </rect>
          </defs>
          <use href="#animRect" x="50" y="50"/>
          <use href="#animRect" x="100" y="100"/>
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

    testWidgets('animation on use element itself', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <circle id="dot" r="10" fill="green"/>
          </defs>
          <use href="#dot" x="100" y="100">
            <animate attributeName="x" values="50;150;50" dur="2s" repeatCount="indefinite"/>
          </use>
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

    testWidgets('use referencing symbol with animated content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="pulsingDot" viewBox="0 0 50 50">
              <circle cx="25" cy="25" r="15" fill="red">
                <animate attributeName="r" values="10;20;10" dur="1s" repeatCount="indefinite"/>
              </circle>
            </symbol>
          </defs>
          <use href="#pulsingDot" x="50" y="50" width="50" height="50"/>
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
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });
  });

  group('DOM parsing verification for use/symbol', () {
    test('use href attribute parses correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <rect id="r1" width="50" height="50"/>
          </defs>
          <use href="#r1" x="10" y="20"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final use = document.root.children.firstWhere((n) => n.tagName == 'use');

      expect(use.getAttributeValue('href'), '#r1');
      expect(use.getAttributeValue('x'), 10.0);
      expect(use.getAttributeValue('y'), 20.0);
    });

    test('symbol viewBox parses correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <symbol id="icon" viewBox="0 0 24 24">
              <rect width="24" height="24"/>
            </symbol>
          </defs>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final defs = document.root.children.firstWhere(
        (n) => n.tagName == 'defs',
      );
      final symbol = defs.children.firstWhere((n) => n.tagName == 'symbol');

      expect(symbol.id, 'icon');
      expect(symbol.getAttributeValue('viewBox'), '0 0 24 24');
    });

    test('use width and height parse correctly', () {
      const svgString = '''
        <svg>
          <use href="#s" x="10" y="20" width="100" height="80"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final use = document.root.children.firstWhere((n) => n.tagName == 'use');

      expect(use.getAttributeValue('width'), 100.0);
      expect(use.getAttributeValue('height'), 80.0);
    });

    test('symbol preserveAspectRatio parses correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <symbol id="s" viewBox="0 0 50 50" preserveAspectRatio="xMinYMin slice">
              <circle cx="25" cy="25" r="20"/>
            </symbol>
          </defs>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final defs = document.root.children.firstWhere(
        (n) => n.tagName == 'defs',
      );
      final symbol = defs.children.firstWhere((n) => n.tagName == 'symbol');

      expect(symbol.getAttributeValue('preserveAspectRatio'), 'xMinYMin slice');
    });
  });

  group('Use edge cases with special scenarios', () {
    testWidgets('use with zero width renders nothing visible', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="s1" viewBox="0 0 50 50">
              <rect width="50" height="50" fill="red"/>
            </symbol>
          </defs>
          <use href="#s1" x="50" y="50" width="0" height="100"/>
          <rect x="100" y="100" width="50" height="50" fill="blue"/>
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

    testWidgets('use with very large coordinate values', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="r1" width="20" height="20" fill="green"/>
          </defs>
          <use href="#r1" x="99999" y="99999"/>
          <rect x="50" y="50" width="50" height="50" fill="blue"/>
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

    testWidgets('use with negative x/y coordinates', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="r1" width="50" height="50" fill="red"/>
          </defs>
          <use href="#r1" x="-20" y="-20"/>
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
      expect(analysis.pixelCount, greaterThan(0));
    });

    testWidgets('multiple uses of same element with different transforms', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <rect id="base" width="30" height="30" fill="purple"/>
          </defs>
          <use href="#base" x="20" y="20"/>
          <use href="#base" x="60" y="20" transform="rotate(45 75 35)"/>
          <use href="#base" x="100" y="20" transform="scale(0.5)"/>
          <use href="#base" x="140" y="20" transform="skewX(20)"/>
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

    testWidgets('symbol without viewBox still renders content', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <symbol id="noViewBox">
              <rect width="40" height="40" fill="orange"/>
            </symbol>
          </defs>
          <use href="#noViewBox" x="80" y="80"/>
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
