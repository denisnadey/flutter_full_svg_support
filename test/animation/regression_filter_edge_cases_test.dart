// Regression tests for filter pipeline edge cases
// Tests complex filter scenarios that have historically caused issues

import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-primitive filter chains', () {
    testWidgets('blur then offset then blend chain', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="chain1">
              <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blur"/>
              <feOffset in="blur" dx="4" dy="4" result="offset"/>
              <feBlend in="SourceGraphic" in2="offset" mode="normal"/>
            </filter>
          </defs>
          <rect x="40" y="40" width="120" height="120" fill="blue" 
                filter="url(#chain1)"/>
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

    testWidgets('color matrix then composite then merge', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="chain2">
              <feColorMatrix in="SourceGraphic" type="saturate" values="0.5" result="saturated"/>
              <feGaussianBlur in="saturated" stdDeviation="3" result="blurred"/>
              <feComposite in="saturated" in2="blurred" operator="over" result="comp"/>
              <feMerge>
                <feMergeNode in="comp"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <circle cx="100" cy="100" r="60" fill="red" filter="url(#chain2)"/>
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

    testWidgets('flood then composite then morphology chain', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="chain3" x="-10%" y="-10%" width="120%" height="120%">
              <feFlood flood-color="orange" flood-opacity="0.7" result="flood"/>
              <feComposite in="flood" in2="SourceAlpha" operator="in" result="comp"/>
              <feMorphology in="comp" operator="dilate" radius="2" result="dilated"/>
              <feMerge>
                <feMergeNode in="dilated"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <text x="50" y="120" font-size="40" filter="url(#chain3)">Hello</text>
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

    testWidgets('turbulence then displacement then blend', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="chain4">
              <feTurbulence type="turbulence" baseFrequency="0.05" numOctaves="2" result="turb"/>
              <feDisplacementMap in="SourceGraphic" in2="turb" scale="10" 
                                 xChannelSelector="R" yChannelSelector="G" result="disp"/>
              <feBlend in="disp" in2="SourceGraphic" mode="multiply"/>
            </filter>
          </defs>
          <rect x="30" y="30" width="140" height="140" fill="green" 
                filter="url(#chain4)"/>
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

    testWidgets('five-stage filter pipeline', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="chain5">
              <feGaussianBlur in="SourceAlpha" stdDeviation="3" result="blur"/>
              <feOffset in="blur" dx="5" dy="5" result="offset"/>
              <feFlood flood-color="black" flood-opacity="0.4" result="flood"/>
              <feComposite in="flood" in2="offset" operator="in" result="shadow"/>
              <feMerge>
                <feMergeNode in="shadow"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <rect x="40" y="40" width="100" height="100" fill="purple" 
                filter="url(#chain5)"/>
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

  group('Filter on group with transforms', () {
    testWidgets('filter on rotated group', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fBlur">
              <feGaussianBlur stdDeviation="2"/>
            </filter>
          </defs>
          <g transform="rotate(45 100 100)" filter="url(#fBlur)">
            <rect x="60" y="60" width="80" height="80" fill="blue"/>
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

    testWidgets('filter on scaled group', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fShadow">
              <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="black" flood-opacity="0.5"/>
            </filter>
          </defs>
          <g transform="scale(0.5) translate(100 100)" filter="url(#fShadow)">
            <circle cx="100" cy="100" r="60" fill="red"/>
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

    testWidgets('filter on nested transformed groups', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fGlow">
              <feGaussianBlur in="SourceAlpha" stdDeviation="4" result="blur"/>
              <feFlood flood-color="yellow" result="flood"/>
              <feComposite in="flood" in2="blur" operator="in" result="glow"/>
              <feMerge>
                <feMergeNode in="glow"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <g transform="translate(50 50)">
            <g transform="rotate(30 50 50)" filter="url(#fGlow)">
              <rect x="20" y="20" width="60" height="60" fill="orange"/>
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

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('filter with matrix transform', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fBlend">
              <feBlend in="SourceGraphic" in2="BackgroundImage" mode="screen"/>
            </filter>
          </defs>
          <g transform="matrix(0.866 0.5 -0.5 0.866 100 0)" filter="url(#fBlend)">
            <rect x="20" y="50" width="60" height="100" fill="cyan"/>
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

  group('Complex filter input graphs', () {
    testWidgets('filter using same result in multiple primitives', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fMulti">
              <feGaussianBlur in="SourceGraphic" stdDeviation="4" result="shared"/>
              <feOffset in="shared" dx="10" dy="10" result="offset1"/>
              <feOffset in="shared" dx="-10" dy="-10" result="offset2"/>
              <feMerge>
                <feMergeNode in="offset1"/>
                <feMergeNode in="offset2"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <rect x="50" y="50" width="100" height="100" fill="magenta" 
                filter="url(#fMulti)"/>
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

    testWidgets('filter with branching and merging paths', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fBranch">
              <feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blur"/>
              <feColorMatrix in="blur" type="hueRotate" values="90" result="hue"/>
              <feColorMatrix in="blur" type="saturate" values="2" result="sat"/>
              <feComposite in="hue" in2="sat" operator="arithmetic" 
                           k1="0" k2="0.5" k3="0.5" k4="0"/>
            </filter>
          </defs>
          <circle cx="100" cy="100" r="70" fill="lime" filter="url(#fBranch)"/>
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

    testWidgets('filter chaining SourceAlpha and SourceGraphic', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fAlphaGraph">
              <feGaussianBlur in="SourceAlpha" stdDeviation="6" result="alphaBlur"/>
              <feOffset in="alphaBlur" dx="6" dy="6" result="shadow"/>
              <feFlood flood-color="#000" flood-opacity="0.5" result="flood"/>
              <feComposite in="flood" in2="shadow" operator="in" result="shadowColored"/>
              <feMerge>
                <feMergeNode in="shadowColored"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <ellipse cx="100" cy="100" rx="70" ry="50" fill="gold" 
                   filter="url(#fAlphaGraph)"/>
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

    testWidgets('filter with implicit in (from previous result)', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fImplicit">
              <feGaussianBlur stdDeviation="3"/>
              <feColorMatrix type="saturate" values="0.3"/>
              <feOffset dx="5" dy="5"/>
            </filter>
          </defs>
          <rect x="40" y="40" width="120" height="120" fill="teal" 
                filter="url(#fImplicit)"/>
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

  group('feColorMatrix edge cases', () {
    testWidgets('matrix type with 20 values', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fMatrix">
              <feColorMatrix type="matrix" 
                values="0.33 0.33 0.33 0 0
                        0.33 0.33 0.33 0 0
                        0.33 0.33 0.33 0 0
                        0 0 0 1 0"/>
            </filter>
          </defs>
          <rect x="20" y="20" width="160" height="160" fill="red" 
                filter="url(#fMatrix)"/>
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

    testWidgets('luminanceToAlpha type', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fLum">
              <feColorMatrix type="luminanceToAlpha"/>
            </filter>
          </defs>
          <rect x="20" y="20" width="160" height="160">
            <linearGradient id="grad">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </linearGradient>
          </rect>
          <rect x="20" y="20" width="160" height="160" fill="url(#grad)" 
                filter="url(#fLum)"/>
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

    testWidgets('hueRotate with negative angle', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fHue">
              <feColorMatrix type="hueRotate" values="-90"/>
            </filter>
          </defs>
          <circle cx="100" cy="100" r="80" fill="red" filter="url(#fHue)"/>
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

    testWidgets('saturate value > 1 for super saturation', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fSat">
              <feColorMatrix type="saturate" values="3"/>
            </filter>
          </defs>
          <rect x="20" y="20" width="160" height="160" fill="#888888" 
                filter="url(#fSat)"/>
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

  group('feComposite operators', () {
    testWidgets('arithmetic operator with k values', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fArith">
              <feFlood flood-color="red" result="red"/>
              <feFlood flood-color="blue" result="blue"/>
              <feComposite in="red" in2="blue" operator="arithmetic" 
                           k1="0" k2="0.5" k3="0.5" k4="0"/>
            </filter>
          </defs>
          <rect x="20" y="20" width="160" height="160" filter="url(#fArith)"/>
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

    testWidgets('xor operator', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fXor">
              <feFlood flood-color="green" x="20" y="20" width="100" height="100" result="g"/>
              <feFlood flood-color="blue" x="80" y="80" width="100" height="100" result="b"/>
              <feComposite in="g" in2="b" operator="xor"/>
            </filter>
          </defs>
          <rect x="0" y="0" width="200" height="200" filter="url(#fXor)"/>
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

    testWidgets('atop operator', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fAtop">
              <feGaussianBlur in="SourceAlpha" stdDeviation="4" result="blur"/>
              <feComposite in="SourceGraphic" in2="blur" operator="atop"/>
            </filter>
          </defs>
          <rect x="40" y="40" width="120" height="120" fill="purple" 
                filter="url(#fAtop)"/>
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

    testWidgets('out operator', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fOut">
              <feGaussianBlur in="SourceAlpha" stdDeviation="8" result="blur"/>
              <feComposite in="blur" in2="SourceAlpha" operator="out"/>
            </filter>
          </defs>
          <circle cx="100" cy="100" r="60" fill="orange" filter="url(#fOut)"/>
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

  group('feBlend modes', () {
    testWidgets('multiply blend mode', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fMult">
              <feFlood flood-color="cyan" result="cyan"/>
              <feBlend in="SourceGraphic" in2="cyan" mode="multiply"/>
            </filter>
          </defs>
          <rect x="30" y="30" width="140" height="140" fill="red" 
                filter="url(#fMult)"/>
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

    testWidgets('screen blend mode', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fScreen">
              <feFlood flood-color="magenta" result="mag"/>
              <feBlend in="SourceGraphic" in2="mag" mode="screen"/>
            </filter>
          </defs>
          <circle cx="100" cy="100" r="70" fill="blue" filter="url(#fScreen)"/>
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

    testWidgets('overlay blend mode', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fOverlay">
              <feFlood flood-color="yellow" result="yellow"/>
              <feBlend in="SourceGraphic" in2="yellow" mode="overlay"/>
            </filter>
          </defs>
          <rect x="20" y="20" width="160" height="160" fill="green" 
                filter="url(#fOverlay)"/>
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

    testWidgets('darken blend mode', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fDarken">
              <feFlood flood-color="gray" result="gray"/>
              <feBlend in="SourceGraphic" in2="gray" mode="darken"/>
            </filter>
          </defs>
          <ellipse cx="100" cy="100" rx="80" ry="50" fill="white" 
                   filter="url(#fDarken)"/>
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

    testWidgets('lighten blend mode', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fLighten">
              <feFlood flood-color="gray" result="gray"/>
              <feBlend in="SourceGraphic" in2="gray" mode="lighten"/>
            </filter>
          </defs>
          <rect x="30" y="30" width="140" height="140" fill="black" 
                filter="url(#fLighten)"/>
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

  group('Filter region edge cases', () {
    testWidgets('filter with custom x, y, width, height', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fRegion" x="-50%" y="-50%" width="200%" height="200%">
              <feGaussianBlur stdDeviation="10"/>
            </filter>
          </defs>
          <rect x="60" y="60" width="80" height="80" fill="blue" 
                filter="url(#fRegion)"/>
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

    testWidgets('filterUnits="userSpaceOnUse"', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fUser" filterUnits="userSpaceOnUse" 
                    x="0" y="0" width="200" height="200">
              <feOffset dx="10" dy="10"/>
            </filter>
          </defs>
          <circle cx="100" cy="100" r="50" fill="red" filter="url(#fUser)"/>
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

    testWidgets('primitiveUnits="objectBoundingBox"', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="fPrim" primitiveUnits="objectBoundingBox">
              <feGaussianBlur stdDeviation="0.05"/>
            </filter>
          </defs>
          <rect x="40" y="40" width="120" height="120" fill="green" 
                filter="url(#fPrim)"/>
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

  group('DOM parsing verification for filters', () {
    test('filter with multiple primitives parses correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <filter id="f1">
              <feGaussianBlur stdDeviation="3" result="blur"/>
              <feOffset dx="5" dy="5" result="offset"/>
              <feMerge>
                <feMergeNode in="offset"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <rect filter="url(#f1)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);

      final filter = document.filters!.getById('f1');
      expect(filter, isNotNull);
    });

    test('feColorMatrix type attribute parses correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <filter id="f1">
              <feColorMatrix type="saturate" values="0.5"/>
            </filter>
          </defs>
          <rect filter="url(#f1)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('f1') as SvgColorMatrixFilter;
      expect(filter.type, SvgFilterType.colorMatrix);
      expect(filter.values, isNotNull);
    });

    test('feComposite arithmetic k values parse correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <filter id="f1">
              <feComposite operator="arithmetic" k1="0.1" k2="0.2" k3="0.3" k4="0.4"/>
            </filter>
          </defs>
          <rect filter="url(#f1)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('f1') as SvgCompositeFilter;
      expect(filter.operatorType, 'arithmetic');
      expect(filter.k1, 0.1);
      expect(filter.k2, 0.2);
      expect(filter.k3, 0.3);
      expect(filter.k4, 0.4);
    });

    test('feGaussianBlur stdDeviation with two values parses correctly', () {
      const svgString = '''
        <svg>
          <defs>
            <filter id="f1">
              <feGaussianBlur stdDeviation="3 5"/>
            </filter>
          </defs>
          <rect filter="url(#f1)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('f1') as SvgGaussianBlurFilter;
      expect(filter.stdDeviationX, 3.0);
      expect(filter.stdDeviationY, 5.0);
    });

    test('feDropShadow parses all attributes', () {
      const svgString = '''
        <svg>
          <defs>
            <filter id="f1">
              <feDropShadow dx="5" dy="5" stdDeviation="3" 
                           flood-color="black" flood-opacity="0.5"/>
            </filter>
          </defs>
          <rect filter="url(#f1)"/>
        </svg>
      ''';

      final document = SvgParser.parse(svgString);
      final filter = document.filters!.getById('f1') as SvgDropShadowFilter;
      expect(filter.dx, 5.0);
      expect(filter.dy, 5.0);
      expect(filter.stdDeviation, 3.0);
      expect(filter.floodOpacity, 0.5);
    });
  });

  group('Filter references and inheritance', () {
    testWidgets('filter referencing another filter via href', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 200 200">
          <defs>
            <filter id="base">
              <feGaussianBlur stdDeviation="2"/>
            </filter>
            <filter id="derived" href="#base">
              <feOffset dx="5" dy="5"/>
            </filter>
          </defs>
          <rect x="40" y="40" width="120" height="120" fill="blue" 
                filter="url(#derived)"/>
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

    testWidgets('multiple elements using same filter', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 300 200">
          <defs>
            <filter id="shared">
              <feDropShadow dx="3" dy="3" stdDeviation="2" flood-color="black" flood-opacity="0.4"/>
            </filter>
          </defs>
          <rect x="20" y="50" width="80" height="80" fill="red" filter="url(#shared)"/>
          <circle cx="190" cy="90" r="40" fill="green" filter="url(#shared)"/>
          <ellipse cx="270" cy="90" rx="30" ry="50" fill="blue" filter="url(#shared)"/>
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
  });
}
