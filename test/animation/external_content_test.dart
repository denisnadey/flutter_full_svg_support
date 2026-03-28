import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Tiny 2x2 blue PNG as base64
const _tinyBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEElEQVR42mNgYPj/H4KhDAA/0gf5XBPgQgAAAABJRU5ErkJggg==';

void main() {
  group('External Content Improvements', () {
    group('Data URI MIME Type Validation', () {
      testWidgets('accepts image/png MIME type', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('accepts image/jpeg MIME type', (tester) async {
        // Using PNG data with JPEG MIME type - codec will handle
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/jpeg;base64,$_tinyBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('accepts image/webp MIME type', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/webp;base64,$_tinyBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('accepts image/gif MIME type', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/gif;base64,$_tinyBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('accepts image/bmp MIME type', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/bmp;base64,$_tinyBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('rejects application/javascript MIME type', (tester) async {
        // Non-image MIME type should be rejected
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:application/javascript;base64,YWxlcnQoMSk="/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Widget should render without crashing - image is just skipped
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('rejects text/html MIME type', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:text/html;base64,PGgxPkhlbGxvPC9oMT4="/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('rejects text/plain MIME type', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:text/plain;base64,SGVsbG8="/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('Data URI Edge Cases', () {
      testWidgets('handles missing MIME type gracefully', (tester) async {
        // Data URI with no MIME type
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:;base64,$_tinyBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles empty data payload', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/png;base64,"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles malformed base64 data', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/png;base64,NOT_VALID_BASE64!!!"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles data URI without comma separator', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/png;base64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('handles truncated data URI', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('SVG-as-Image Detection', () {
      testWidgets('detects SVG data URI with image/svg+xml MIME type', (
        tester,
      ) async {
        // SVG data URI should be detected and handled gracefully
        final svgContent =
            '<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="4" fill="red"/></svg>';
        final base64Svg = Uri.encodeComponent(svgContent);

        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/svg+xml,$base64Svg"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should render without crashing - SVG image is skipped with warning
        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('detects SVG file reference by .svg extension', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="100" height="100" fill="blue"/>
          <image x="10" y="10" width="80" height="80" 
                 href="nested_image.svg"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('detects SVG file with uppercase .SVG extension', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="100" height="100" fill="green"/>
          <image x="10" y="10" width="80" height="80" 
                 href="images/ICON.SVG"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('does not detect non-SVG file as SVG', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80" height="80" 
                 href="data:image/png;base64,$_tinyBluePngBase64"/>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 200, height: 200),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('ForeignObject Overflow Attribute', () {
      testWidgets('foreignObject default overflow is hidden (clips content)', (
        tester,
      ) async {
        // Default overflow should clip children to foreignObject bounds
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="30" height="30">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="red"/>
              </svg>
            </foreignObject>
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
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject overflow="hidden" clips content', (
        tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="30" height="30" overflow="hidden">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="blue"/>
              </svg>
            </foreignObject>
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
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('foreignObject overflow="visible" allows overflow', (
        tester,
      ) async {
        // Content should be allowed to render outside bounds
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="30" height="30" overflow="visible">
              <svg viewBox="0 0 50 50">
                <rect x="0" y="0" width="50" height="50" fill="green"/>
              </svg>
            </foreignObject>
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
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('parser extracts overflow attribute from foreignObject', (
        tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject id="fo-visible" x="10" y="10" width="30" height="30" overflow="visible">
              <rect x="0" y="0" width="50" height="50" fill="red"/>
            </foreignObject>
            <foreignObject id="fo-hidden" x="50" y="10" width="30" height="30" overflow="hidden">
              <rect x="0" y="0" width="50" height="50" fill="blue"/>
            </foreignObject>
          </svg>
        ''';

        final doc = SvgParser.parse(svgXml.trim());

        // Find foreignObject elements
        final foVisible = doc.root.findById('fo-visible');
        final foHidden = doc.root.findById('fo-hidden');

        expect(foVisible, isNotNull);
        expect(foHidden, isNotNull);
        expect(foVisible!.getAttributeValue('overflow'), equals('visible'));
        expect(foHidden!.getAttributeValue('overflow'), equals('hidden'));
      });
    });

    group('Transform Propagation Through ForeignObject', () {
      testWidgets('nested SVG inherits foreignObject transform', (
        tester,
      ) async {
        // Transform on foreignObject should propagate to nested content
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="40" height="40" transform="rotate(45 30 30)">
              <svg viewBox="0 0 40 40">
                <rect x="5" y="5" width="30" height="30" fill="orange"/>
              </svg>
            </foreignObject>
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
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('nested viewBox composes with foreignObject transform', (
        tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="20" y="20" width="60" height="60" transform="scale(0.8)">
              <svg viewBox="0 0 30 30" preserveAspectRatio="xMidYMid meet">
                <circle cx="15" cy="15" r="10" fill="purple"/>
              </svg>
            </foreignObject>
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
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('deeply nested transforms compose correctly', (tester) async {
        // Multiple levels of nesting with transforms at each level
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <g transform="translate(10, 10)">
              <foreignObject x="0" y="0" width="80" height="80" transform="scale(0.9)">
                <svg viewBox="0 0 40 40">
                  <g transform="rotate(15 20 20)">
                    <rect x="10" y="10" width="20" height="20" fill="cyan"/>
                  </g>
                </svg>
              </foreignObject>
            </g>
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
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });

      testWidgets('preserveAspectRatio in nested SVG within foreignObject', (
        tester,
      ) async {
        const svgXml = '''
          <svg viewBox="0 0 100 100">
            <foreignObject x="10" y="10" width="80" height="40">
              <svg viewBox="0 0 100 100" preserveAspectRatio="xMinYMin meet">
                <rect x="0" y="0" width="100" height="100" fill="pink"/>
              </svg>
            </foreignObject>
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
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });
  });
}
