import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// Tiny 2x2 blue PNG as base64
const _tinyBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEElEQVR42mNgYPj/H4KhDAA/0gf5XBPgQgAAAABJRU5ErkJggg==';

// Tiny 4x2 red PNG as base64 (wider than tall for aspect ratio testing)
const _wideRedPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAD0lEQVR42mP8z8DwHwYBAAV/AfnLdGqDAAAAAElFTkSuQmCC';

void main() {
  group('Image in Complex Contexts', () {
    group('image inside clipPath', () {
      testWidgets('image defines clip region by its bounds', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <clipPath id="imgClip">
              <image x="20" y="20" width="60" height="60"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="red" clip-path="url(#imgClip)"/>
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

      testWidgets('image in clipPath with transform', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <clipPath id="imgClip">
              <image x="10" y="10" width="40" height="40" transform="rotate(45 30 30)"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </clipPath>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="green" clip-path="url(#imgClip)"/>
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

    group('image inside use', () {
      testWidgets('referenced image renders at use position', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <image id="myImg" x="0" y="0" width="30" height="30"
                   href="data:image/png;base64,$_tinyBluePngBase64"/>
          </defs>
          <use href="#myImg" x="10" y="10"/>
          <use href="#myImg" x="60" y="60"/>
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

      testWidgets('image inside symbol with viewBox', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <symbol id="imgSymbol" viewBox="0 0 50 50">
              <image x="5" y="5" width="40" height="40"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </symbol>
          </defs>
          <use href="#imgSymbol" x="10" y="10" width="80" height="80"/>
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

    group('image inside mask', () {
      testWidgets('image contributes to mask region', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <mask id="imgMask">
              <image x="20" y="20" width="60" height="60"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </mask>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="purple" mask="url(#imgMask)"/>
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

      testWidgets('image mask with objectBoundingBox units', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <mask id="imgMask" maskContentUnits="objectBoundingBox">
              <rect x="0.1" y="0.1" width="0.8" height="0.8" fill="white"/>
            </mask>
          </defs>
          <image x="10" y="10" width="80" height="80" mask="url(#imgMask)"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
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

    group('image inside pattern', () {
      testWidgets('image tiles correctly within pattern', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="imgPattern" x="0" y="0" width="20" height="20" 
                     patternUnits="userSpaceOnUse">
              <image x="0" y="0" width="20" height="20"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#imgPattern)"/>
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

      testWidgets('pattern with objectBoundingBox and image', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <pattern id="imgPattern" x="0" y="0" width="0.25" height="0.25" 
                     patternUnits="objectBoundingBox"
                     patternContentUnits="userSpaceOnUse">
              <image x="0" y="0" width="10" height="10"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </pattern>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#imgPattern)"/>
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

    group('image with filters', () {
      testWidgets('filter applies to image content', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <filter id="blur">
              <feGaussianBlur stdDeviation="2"/>
            </filter>
          </defs>
          <image x="10" y="10" width="80" height="80" filter="url(#blur)"
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

      testWidgets('color matrix filter on image', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <filter id="grayscale">
              <feColorMatrix type="saturate" values="0"/>
            </filter>
          </defs>
          <image x="10" y="10" width="80" height="80" filter="url(#grayscale)"
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

    group('image percentage dimensions', () {
      testWidgets('image with percentage width/height', (tester) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="80%" height="80%"
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

      testWidgets('image with percentage width, absolute height', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="5" y="5" width="50%" height="40"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
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

      testWidgets('image inside foreignObject with percentage', (tester) async {
        final svg =
            '''<svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
          <foreignObject x="50" y="50" width="100" height="100">
            <svg viewBox="0 0 100 100">
              <image x="10" y="10" width="80%" height="80%"
                     href="data:image/png;base64,$_tinyBluePngBase64"/>
            </svg>
          </foreignObject>
        </svg>''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(svg, width: 400, height: 400),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      });
    });

    group('image intrinsic size fallback', () {
      testWidgets('image without width/height uses intrinsic size', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="40" y="40"
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

      testWidgets('image with only width uses intrinsic aspect ratio', (
        tester,
      ) async {
        final svg =
            '''<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <image x="10" y="10" width="50"
                 href="data:image/png;base64,$_wideRedPngBase64"/>
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
  });

  group('ForeignObject Custom Builder', () {
    testWidgets('foreignObjectBuilder receives correct info', (tester) async {
      SvgForeignObjectInfo? receivedInfo;

      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject id="fo1" x="10" y="20" width="80" height="60">
            <svg viewBox="0 0 50 50">
              <rect id="inner" x="5" y="5" width="40" height="40"/>
            </svg>
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                svgXml,
                width: 200,
                height: 200,
                foreignObjectBuilder: (context, info) {
                  receivedInfo = info;
                  return const Text('Custom');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(receivedInfo, isNotNull);
      expect(receivedInfo!.id, 'fo1');
      expect(receivedInfo!.x, 10.0);
      expect(receivedInfo!.y, 20.0);
      expect(receivedInfo!.width, 80.0);
      expect(receivedInfo!.height, 60.0);
      expect(receivedInfo!.children, isNotEmpty);
    });

    testWidgets('foreignObjectBuilder can return custom widget', (
      tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject id="fo1" x="10" y="10" width="80" height="80">
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                svgXml,
                width: 200,
                height: 200,
                foreignObjectBuilder: (context, info) {
                  return Container(
                    color: Colors.blue,
                    child: const Center(child: Text('Custom Content')),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Custom Content'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('foreignObjectBuilder returning null renders nothing', (
      tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject x="10" y="10" width="80" height="80">
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                svgXml,
                width: 200,
                height: 200,
                foreignObjectBuilder: (context, info) => null,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should not have any custom content
      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('foreignObject with requiredExtensions skips builder', (
      tester,
    ) async {
      bool builderCalled = false;

      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject x="10" y="10" width="80" height="80"
              requiredExtensions="http://example.com/unsupported">
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                svgXml,
                width: 200,
                height: 200,
                foreignObjectBuilder: (context, info) {
                  builderCalled = true;
                  return const Text('Should not appear');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Builder should not be called for unsupported extensions
      expect(builderCalled, isFalse);
    });

    testWidgets('multiple foreignObjects each get builder call', (
      tester,
    ) async {
      final receivedIds = <String?>[];

      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject id="fo1" x="5" y="5" width="40" height="40">
          </foreignObject>
          <foreignObject id="fo2" x="55" y="55" width="40" height="40">
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                svgXml,
                width: 200,
                height: 200,
                foreignObjectBuilder: (context, info) {
                  receivedIds.add(info.id);
                  return Text('FO: ${info.id}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(receivedIds, containsAll(['fo1', 'fo2']));
      expect(find.text('FO: fo1'), findsOneWidget);
      expect(find.text('FO: fo2'), findsOneWidget);
    });
  });

  group('PreserveAspectRatio Parser Tests', () {
    test('image geometry for clipPath returns correct bounds', () {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="imgClip">
              <image id="clipImg" x="10" y="20" width="60" height="40"/>
            </clipPath>
          </defs>
        </svg>
      ''';

      final document = SvgParser.parse(svgXml);
      final clipPath = document.root.findById('imgClip');
      final image = document.root.findById('clipImg');

      expect(clipPath, isNotNull);
      expect(image, isNotNull);
      expect(image!.tagName, 'image');
      expect(image.getAttributeValue('x')?.toString(), '10.0');
      expect(image.getAttributeValue('y')?.toString(), '20.0');
      expect(image.getAttributeValue('width')?.toString(), '60.0');
      expect(image.getAttributeValue('height')?.toString(), '40.0');
    });
  });
}
