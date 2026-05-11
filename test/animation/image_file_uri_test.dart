import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';
import 'package:full_svg_flutter/src/utilities/file.dart';

// Tiny 2×2 blue PNG
const _tinyBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEElEQVR42mNgYPj/H4KhDAA/0gf5XBPgQgAAAABJRU5ErkJggg==';

Uint8List get _tinyBluePngBytes =>
    Uint8List.fromList(base64.decode(_tinyBluePngBase64));

// ── Unit tests for readFileBytes ─────────────────────────────────────────────

void main() {
  group('readFileBytes', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('svg_file_uri_unit_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('returns correct bytes for an existing file', () async {
      final file = File('${tempDir.path}/test.png');
      await file.writeAsBytes(_tinyBluePngBytes);

      final result = await readFileBytes(file.uri);

      expect(result, isNotNull);
      expect(result, equals(_tinyBluePngBytes));
    });

    test('returns null for a nonexistent file', () async {
      final result = await readFileBytes(
        Uri.file('${tempDir.path}/no_such_file.png'),
      );
      expect(result, isNull);
    });

    test('returns null for a directory URI', () async {
      final result = await readFileBytes(Uri.directory(tempDir.path));
      expect(result, isNull);
    });
  });

  // ── Widget tests ─────────────────────────────────────────────────────────
  //
  // Image loading is fire-and-forget (unawaited) inside AnimatedSvgPicture.
  // In Flutter's FakeAsync test environment, real dart:io cannot be awaited
  // via pump(), so these tests only verify no exception is thrown at mount
  // time. The readFileBytes unit tests above cover the I/O correctness.

  group('file:// image in SVG (no crash)', () {
    const noImageSvg =
        '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
        '<image x="10" y="10" width="80" height="80" href="file:///nonexistent/image.png"/>'
        '</svg>';

    testWidgets('mounts without crash for nonexistent file:// href',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(noImageSvg, width: 200, height: 200),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('imageLoader takes priority over file:// native loading',
        (tester) async {
      const href = 'file:///some/image.png';
      const svg =
          '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
          '<image x="10" y="10" width="80" height="80" href="$href"/>'
          '</svg>';

      var loaderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svg,
              width: 200,
              height: 200,
              imageLoader: (h) async {
                if (h == href) loaderCalled = true;
                // Return null so the built-in loader chain continues;
                // what matters is that our callback was reached first.
                return null;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Give the unawaited image-load microtasks a chance to start.
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      expect(loaderCalled, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
