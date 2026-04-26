import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gradient units', () {
    group('gradientUnits="objectBoundingBox"', () {
      testWidgets('linear gradient with objectBoundingBox units (default)', (
        tester,
      ) async {
        // objectBoundingBox is the default for gradientUnits
        // Coordinates 0-1 map to element bounding box
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1">
              <stop offset="0%" stop-color="red"/>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect x="50" y="25" width="100" height="50" fill="url(#grad1)"/>
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

      testWidgets(
        'linear gradient with explicit objectBoundingBox and fractional coords',
        (tester) async {
          // Coordinates as fractions (0.0 to 1.0) of element bounding box
          const svg =
              '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1" gradientUnits="objectBoundingBox"
                            x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stop-color="yellow"/>
              <stop offset="1" stop-color="green"/>
            </linearGradient>
          </defs>
          <rect x="20" y="20" width="160" height="60" fill="url(#grad1)"/>
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
        },
      );

      testWidgets(
        'linear gradient with objectBoundingBox and percentage coords',
        (tester) async {
          // Percentage values (0% to 100%) of element bounding box
          const svg =
              '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1" gradientUnits="objectBoundingBox"
                            x1="0%" y1="50%" x2="100%" y2="50%">
              <stop offset="0%" stop-color="purple"/>
              <stop offset="100%" stop-color="orange"/>
            </linearGradient>
          </defs>
          <ellipse cx="100" cy="50" rx="80" ry="40" fill="url(#grad1)"/>
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
        },
      );

      testWidgets('radial gradient with objectBoundingBox units (default)', (
        tester,
      ) async {
        // Default is objectBoundingBox, cx/cy/r are fractions of bounding box
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad1">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
          </defs>
          <rect x="50" y="25" width="100" height="50" fill="url(#grad1)"/>
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

      testWidgets('radial gradient with objectBoundingBox explicit coords', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad1" gradientUnits="objectBoundingBox"
                            cx="0.5" cy="0.5" r="0.5">
              <stop offset="0" stop-color="cyan"/>
              <stop offset="1" stop-color="magenta"/>
            </radialGradient>
          </defs>
          <circle cx="100" cy="50" r="40" fill="url(#grad1)"/>
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

    group('gradientUnits="userSpaceOnUse"', () {
      testWidgets('linear gradient with userSpaceOnUse coordinates', (
        tester,
      ) async {
        // Coordinates are in user space (same as the element coordinates)
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1" gradientUnits="userSpaceOnUse"
                            x1="50" y1="25" x2="150" y2="75">
              <stop offset="0%" stop-color="red"/>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect x="50" y="25" width="100" height="50" fill="url(#grad1)"/>
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

      testWidgets('radial gradient with userSpaceOnUse coordinates', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad1" gradientUnits="userSpaceOnUse"
                            cx="100" cy="50" r="40">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
          </defs>
          <rect x="50" y="10" width="100" height="80" fill="url(#grad1)"/>
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

      testWidgets(
        'linear gradient userSpaceOnUse with percentage in user coords',
        (tester) async {
          // Percentage values in userSpaceOnUse refer to the element bounding box
          const svg =
              '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="grad1" gradientUnits="userSpaceOnUse"
                            x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stop-color="lime"/>
              <stop offset="100%" stop-color="navy"/>
            </linearGradient>
          </defs>
          <rect x="0" y="0" width="200" height="100" fill="url(#grad1)"/>
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
        },
      );
    });

    group('radial gradient focal point', () {
      testWidgets('radial gradient with fx,fy different from cx,cy', (
        tester,
      ) async {
        // Focal point offset creates a non-concentric gradient
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad1" cx="50%" cy="50%" r="50%" fx="30%" fy="30%">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="darkblue"/>
            </radialGradient>
          </defs>
          <rect x="25" y="12" width="150" height="76" fill="url(#grad1)"/>
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

      testWidgets('radial gradient with fx,fy userSpaceOnUse', (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad1" gradientUnits="userSpaceOnUse"
                            cx="100" cy="50" r="40" fx="80" fy="40">
              <stop offset="0%" stop-color="yellow"/>
              <stop offset="100%" stop-color="red"/>
            </radialGradient>
          </defs>
          <circle cx="100" cy="50" r="45" fill="url(#grad1)"/>
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

      testWidgets('radial gradient with focal radius fr', (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="grad1" cx="50%" cy="50%" r="50%" 
                            fx="30%" fy="30%" fr="10%">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="purple"/>
            </radialGradient>
          </defs>
          <rect x="20" y="10" width="160" height="80" fill="url(#grad1)"/>
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

    group('gradient in nested SVG', () {
      testWidgets('gradient defined in nested svg with viewBox', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <svg x="50" y="25" width="100" height="50" viewBox="0 0 50 25">
            <defs>
              <linearGradient id="nestedGrad" gradientUnits="userSpaceOnUse"
                              x1="0" y1="0" x2="50" y2="25">
                <stop offset="0%" stop-color="gold"/>
                <stop offset="100%" stop-color="darkgreen"/>
              </linearGradient>
            </defs>
            <rect x="0" y="0" width="50" height="25" fill="url(#nestedGrad)"/>
          </svg>
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

      testWidgets('gradient used across nested svg boundaries', (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="sharedGrad" gradientUnits="objectBoundingBox">
              <stop offset="0%" stop-color="teal"/>
              <stop offset="100%" stop-color="coral"/>
            </linearGradient>
          </defs>
          <svg x="10" y="10" width="80" height="80" viewBox="0 0 40 40">
            <rect x="0" y="0" width="40" height="40" fill="url(#sharedGrad)"/>
          </svg>
          <rect x="110" y="10" width="80" height="80" fill="url(#sharedGrad)"/>
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

    group('gradient stop offset animation', () {
      testWidgets('animated stop offset via SMIL animate', (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="animGrad">
              <stop offset="0%" stop-color="red"/>
              <stop offset="50%" stop-color="yellow">
                <animate attributeName="offset" 
                         from="0.5" to="0.9" 
                         dur="2s" repeatCount="indefinite"/>
              </stop>
              <stop offset="100%" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#animGrad)"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('multiple animated stop offsets', (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="multiAnimGrad">
              <stop offset="0%" stop-color="green">
                <animate attributeName="offset" 
                         values="0;0.2;0" 
                         dur="3s" repeatCount="indefinite"/>
              </stop>
              <stop offset="50%" stop-color="white"/>
              <stop offset="100%" stop-color="green">
                <animate attributeName="offset" 
                         values="1;0.8;1" 
                         dur="3s" repeatCount="indefinite"/>
              </stop>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#multiAnimGrad)"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 100),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });

  group('pattern units', () {
    group('patternUnits', () {
      testWidgets('patternUnits="objectBoundingBox" with fractional coords', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="pat1" patternUnits="objectBoundingBox" 
                     width="0.2" height="0.2">
              <rect width="100%" height="100%" fill="lightblue"/>
              <circle cx="50%" cy="50%" r="25%" fill="darkblue"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#pat1)"/>
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

      testWidgets('patternUnits="userSpaceOnUse" with absolute coords', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="pat1" patternUnits="userSpaceOnUse" 
                     x="0" y="0" width="20" height="20">
              <rect width="10" height="10" fill="red"/>
              <rect x="10" y="10" width="10" height="10" fill="red"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#pat1)"/>
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

    group('patternContentUnits', () {
      testWidgets('patternContentUnits="objectBoundingBox"', (tester) async {
        // Pattern content coordinates scaled relative to element bounding box
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="pat1" patternUnits="userSpaceOnUse" 
                     patternContentUnits="objectBoundingBox"
                     width="20" height="20">
              <circle cx="0.5" cy="0.5" r="0.1" fill="green"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="100" height="80" fill="url(#pat1)"/>
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

      testWidgets('patternContentUnits="userSpaceOnUse" (default)', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="pat1" patternUnits="userSpaceOnUse" 
                     patternContentUnits="userSpaceOnUse"
                     width="20" height="20">
              <rect width="10" height="10" fill="orange"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#pat1)"/>
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

      testWidgets('combined objectBoundingBox units', (tester) async {
        // Both patternUnits and patternContentUnits as objectBoundingBox
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="pat1" 
                     patternUnits="objectBoundingBox" 
                     patternContentUnits="objectBoundingBox"
                     width="0.25" height="0.25">
              <rect width="1" height="1" fill="pink"/>
              <rect x="0.25" y="0.25" width="0.5" height="0.5" fill="hotpink"/>
            </pattern>
          </defs>
          <rect x="20" y="10" width="160" height="80" fill="url(#pat1)"/>
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

    group('pattern edge cases', () {
      testWidgets('pattern with width=0 does not render (no error)', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="zeroPat" patternUnits="userSpaceOnUse" 
                     width="0" height="20">
              <rect width="10" height="10" fill="red"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#zeroPat)" stroke="black"/>
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

        // Should render without error (rect just won't have pattern fill)
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('pattern with height=0 does not render (no error)', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="zeroPat" patternUnits="userSpaceOnUse" 
                     width="20" height="0">
              <rect width="10" height="10" fill="blue"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#zeroPat)" stroke="black"/>
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

      testWidgets('pattern with negative width treated as 0 (no error)', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="negPat" patternUnits="userSpaceOnUse" 
                     width="-20" height="20">
              <rect width="10" height="10" fill="green"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#negPat)" stroke="black"/>
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

      testWidgets('pattern with negative height treated as 0 (no error)', (
        tester,
      ) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="negPat" patternUnits="userSpaceOnUse" 
                     width="20" height="-20">
              <rect width="10" height="10" fill="purple"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#negPat)" stroke="black"/>
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

      testWidgets('pattern with both width and height zero', (tester) async {
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="zeroPat" patternUnits="userSpaceOnUse" 
                     width="0" height="0">
              <rect width="10" height="10" fill="red"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#zeroPat)" stroke="black"/>
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

      testWidgets('pattern objectBoundingBox with resulting zero tile size', (
        tester,
      ) async {
        // When objectBoundingBox results in zero tile size
        const svg =
            '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="smallPat" patternUnits="objectBoundingBox" 
                     width="0" height="0.1">
              <rect width="100%" height="100%" fill="cyan"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="180" height="80" fill="url(#smallPat)" stroke="black"/>
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
  });

  group('gradient edge cases', () {
    testWidgets('gradient with zero radius (radial)', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <radialGradient id="zeroRad" cx="50%" cy="50%" r="0">
            <stop offset="0%" stop-color="red"/>
            <stop offset="100%" stop-color="blue"/>
          </radialGradient>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#zeroRad)" stroke="black"/>
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

    testWidgets('gradient with single stop', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="singleStop">
            <stop offset="50%" stop-color="green"/>
          </linearGradient>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#singleStop)"/>
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

    testWidgets('gradient with no stops', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="noStops">
          </linearGradient>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#noStops)" stroke="black"/>
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

    testWidgets('gradient with gradientTransform', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="transformed" gradientTransform="rotate(45)">
            <stop offset="0%" stop-color="orange"/>
            <stop offset="100%" stop-color="purple"/>
          </linearGradient>
        </defs>
        <rect x="25" y="12" width="150" height="76" fill="url(#transformed)"/>
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

    testWidgets('gradient with spreadMethod repeat', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="repeatGrad" spreadMethod="repeat"
                          x1="0%" y1="0%" x2="25%" y2="0%">
            <stop offset="0%" stop-color="red"/>
            <stop offset="100%" stop-color="yellow"/>
          </linearGradient>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#repeatGrad)"/>
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

    testWidgets('gradient with spreadMethod reflect', (tester) async {
      const svg =
          '''<svg viewBox="0 0 200 100" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="reflectGrad" spreadMethod="reflect"
                          x1="0%" y1="0%" x2="25%" y2="0%">
            <stop offset="0%" stop-color="blue"/>
            <stop offset="100%" stop-color="white"/>
          </linearGradient>
        </defs>
        <rect x="10" y="10" width="180" height="80" fill="url(#reflectGrad)"/>
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
}
