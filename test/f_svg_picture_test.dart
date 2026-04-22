import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _FakeAssetBundle extends Fake implements AssetBundle {
  _FakeAssetBundle(this._svgData);

  final String _svgData;

  @override
  Future<String> loadString(String key, {bool cache = true}) async => _svgData;

  @override
  Future<ByteData> load(String key) async {
    return Uint8List.fromList(utf8.encode(_svgData)).buffer.asByteData();
  }
}

class _FakeHttpClient extends Fake implements http.Client {
  _FakeHttpClient(this._svgData);

  final String _svgData;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return http.Response(_svgData, 200);
  }
}

void main() {
  group('FSvgPicture auto pipeline', () {
    testWidgets('uses SvgPicture for static SVG string', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FSvgPicture.string(_staticSvg, width: 100, height: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SvgPicture), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is AnimatedSvgPicture),
        findsNothing,
      );
    });

    testWidgets('uses AnimatedSvgPicture for animated SVG string', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FSvgPicture.string(_animatedSvg, width: 100, height: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byWidgetPredicate((w) => w is AnimatedSvgPicture),
        findsWidgets,
      );
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('supports asset source with auto-detection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FSvgPicture.asset(
              'animated.svg',
              bundle: _FakeAssetBundle(_animatedSvg),
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byWidgetPredicate((w) => w is AnimatedSvgPicture),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('supports network source with auto-detection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FSvgPicture.network(
              'https://example.com/animated.svg',
              httpClient: _FakeHttpClient(_animatedSvg),
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byWidgetPredicate((w) => w is AnimatedSvgPicture),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AnimatedSvgPicture source constructors', () {
    testWidgets('AnimatedSvgPicture.asset works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.asset(
              'animated.svg',
              bundle: _FakeAssetBundle(_animatedSvg),
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byWidgetPredicate((w) => w is AnimatedSvgPicture),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnimatedSvgPicture.network works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.network(
              'https://example.com/animated.svg',
              httpClient: _FakeHttpClient(_animatedSvg),
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byWidgetPredicate((w) => w is AnimatedSvgPicture),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnimatedSvgPicture.file works', (tester) async {
      final file = File(
        '${Directory.systemTemp.path}/flutter_svg_animated_${DateTime.now().microsecondsSinceEpoch}.svg',
      );
      file.writeAsStringSync(_animatedSvg);
      addTearDown(() async {
        if (file.existsSync()) {
          await file.delete();
        }
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.file(file, width: 100, height: 100),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byWidgetPredicate((w) => w is AnimatedSvgPicture),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnimatedSvgPicture.memory works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.memory(
              Uint8List.fromList(utf8.encode(_animatedSvg)),
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byWidgetPredicate((w) => w is AnimatedSvgPicture),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

const _staticSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect x="10" y="10" width="80" height="80" fill="#2196f3"/>
</svg>
''';

const _animatedSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <circle cx="20" cy="50" r="10" fill="red">
    <animate attributeName="cx" from="20" to="80" dur="2s" repeatCount="indefinite"/>
  </circle>
</svg>
''';
