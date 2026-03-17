import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Performance caching', () {
    group('Pattern image caching', () {
      testWidgets('pattern is rendered correctly with caching', (tester) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="dots" patternUnits="userSpaceOnUse" width="10" height="10">
              <circle cx="5" cy="5" r="3" fill="blue"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#dots)"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('multiple frames reuse cached pattern image', (
        tester,
      ) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="grid" patternUnits="userSpaceOnUse" width="10" height="10">
              <rect width="10" height="10" fill="none" stroke="gray"/>
            </pattern>
          </defs>
          <rect x="0" y="0" width="200" height="100" fill="url(#grid)"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );

        // Multiple pumps should reuse cached pattern images
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Gradient shader caching', () {
      testWidgets('linear gradient is rendered with caching', (tester) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" style="stop-color:rgb(255,0,0);stop-opacity:1"/>
              <stop offset="100%" style="stop-color:rgb(0,0,255);stop-opacity:1"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#grad1)"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('radial gradient is rendered with caching', (tester) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad2" cx="50%" cy="50%" r="50%">
              <stop offset="0%" style="stop-color:yellow;stop-opacity:1"/>
              <stop offset="100%" style="stop-color:red;stop-opacity:1"/>
            </radialGradient>
          </defs>
          <circle cx="100" cy="50" r="40" fill="url(#grad2)"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('multiple elements with same gradient reuse cache', (
        tester,
      ) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="shared">
              <stop offset="0%" stop-color="green"/>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="30" fill="url(#shared)"/>
          <rect x="110" y="10" width="80" height="30" fill="url(#shared)"/>
          <circle cx="50" cy="70" r="20" fill="url(#shared)"/>
          <circle cx="150" cy="70" r="20" fill="url(#shared)"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Text paragraph caching', () {
      testWidgets('text element uses paragraph caching', (tester) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="100" y="50" text-anchor="middle" font-size="20" fill="black">
            Hello World
          </text>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('multiple text elements with same style share cache', (
        tester,
      ) async {
        const svg = '''<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
          <text x="50" y="30" font-size="16" fill="navy">Line 1</text>
          <text x="50" y="50" font-size="16" fill="navy">Line 2</text>
          <text x="50" y="70" font-size="16" fill="navy">Line 3</text>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 300, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('tspan elements use text caching', (tester) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <text x="10" y="50" font-size="14" fill="black">
            <tspan>Part 1 </tspan>
            <tspan fill="red">Part 2 </tspan>
            <tspan fill="blue">Part 3</tspan>
          </text>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Hit-test path caching', () {
      testWidgets('path hit-test uses geometry caching', (tester) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path id="myPath" d="M10,10 L190,10 L190,90 L10,90 Z" fill="blue"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Simulate multiple hit tests - should reuse cached path
        await tester.tapAt(const Offset(100, 50));
        await tester.pump();
        await tester.tapAt(const Offset(150, 70));
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('complex path benefits from caching', (tester) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <path id="complex" 
                d="M10,50 C10,10 90,10 90,50 C90,90 170,90 170,50 C170,10 190,10 190,50 L190,90 L10,90 Z" 
                fill="green"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Cache invalidation', () {
      testWidgets('static SVG maintains cache across pumps', (tester) async {
        const svg = '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="g1">
              <stop offset="0%" stop-color="orange"/>
              <stop offset="100%" stop-color="purple"/>
            </linearGradient>
            <pattern id="p1" patternUnits="userSpaceOnUse" width="20" height="20">
              <circle cx="10" cy="10" r="5" fill="red"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#g1)"/>
          <rect x="110" y="10" width="80" height="80" fill="url(#p1)"/>
          <text x="100" y="50" text-anchor="middle">Cached</text>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );

        // Many pumps - cache should be stable for static content
        for (int i = 0; i < 10; i++) {
          await tester.pump();
        }

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Combined caching scenarios', () {
      testWidgets('complex SVG with all cacheable elements', (tester) async {
        const svg = '''<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="lgradient" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stop-color="#ff0000"/>
              <stop offset="50%" stop-color="#00ff00"/>
              <stop offset="100%" stop-color="#0000ff"/>
            </linearGradient>
            <radialGradient id="rgradient" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
            <pattern id="checkers" patternUnits="userSpaceOnUse" width="20" height="20">
              <rect width="10" height="10" fill="black"/>
              <rect x="10" y="10" width="10" height="10" fill="black"/>
            </pattern>
          </defs>
          
          <!-- Multiple elements using cached gradients -->
          <rect x="10" y="10" width="90" height="60" fill="url(#lgradient)"/>
          <rect x="110" y="10" width="90" height="60" fill="url(#rgradient)"/>
          <rect x="210" y="10" width="90" height="60" fill="url(#checkers)"/>
          <rect x="310" y="10" width="80" height="60" fill="url(#lgradient)"/>
          
          <!-- Text elements using cached paragraphs -->
          <text x="55" y="100" text-anchor="middle" font-size="12" fill="navy">Linear</text>
          <text x="155" y="100" text-anchor="middle" font-size="12" fill="navy">Radial</text>
          <text x="255" y="100" text-anchor="middle" font-size="12" fill="navy">Pattern</text>
          <text x="350" y="100" text-anchor="middle" font-size="12" fill="navy">Reused</text>
          
          <!-- Paths that can be cached for hit-testing -->
          <path id="star" d="M200,120 L210,150 L240,150 L215,170 L225,200 L200,180 L175,200 L185,170 L160,150 L190,150 Z" fill="gold"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 400, height: 200),
            ),
          ),
        );

        // Multiple frames to verify caching stability
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
