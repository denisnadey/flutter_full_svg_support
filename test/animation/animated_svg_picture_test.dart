import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

const _tinyBluePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEElEQVR42mNgYPj/H4KhDAA/0gf5XBPgQgAAAABJRU5ErkJggg==';

void main() {
  group('AnimatedSvgPicture', () {
    testWidgets('renders static rect', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="20" width="30" height="40" fill="#ff0000"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders animated rect', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="20" height="20" fill="blue">
            <animate attributeName="x" from="0" to="80" dur="1s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: false, // Не автостарт для тестирования
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('animates x attribute over time', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="20" height="20" fill="red">
            <animate attributeName="x" from="0" to="80" dur="1s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      // Начальное состояние
      await tester.pump();

      // Анимация должна запуститься
      // Проверяем что CustomPaint существует
      expect(find.byType(CustomPaint), findsWidgets);

      // Продвигаем время на половину анимации (500ms)
      await tester.pump(const Duration(milliseconds: 500));

      // Виджет должен перерисоваться
      expect(find.byType(CustomPaint), findsWidgets);

      // Завершаем анимацию (ещё 500ms)
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders circle', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="25" fill="green"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders ellipse', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <ellipse cx="50" cy="50" rx="40" ry="20" fill="yellow"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders path shape', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <path d="M10 10 L90 10 L50 90 Z" fill="red"/>
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

      expect(analysis.pixelCount, greaterThan(2000));
    });

    testWidgets('renders polygon shape', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <polygon points="10,10 90,10 50,90" fill="red"/>
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
      expect(analysis.pixelCount, greaterThan(2000));
    });

    testWidgets('renders polyline shape', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <polyline points="10,80 30,20 50,80 70,20 90,80"
            fill="none" stroke="red" stroke-width="6"/>
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
      expect(analysis.pixelCount, greaterThan(800));
    });

    testWidgets('renders text element', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <text x="10" y="60" font-size="40" fill="#ff0000">TEST</text>
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
      final redPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 170 && g < 120 && b < 120 && a > 200,
      );
      expect(redPixels, greaterThan(1200));
    });

    testWidgets('renders tspan children with inherited text position', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <text x="10" y="60" font-size="36">
            <tspan fill="#ff0000">A</tspan>
            <tspan dx="8" fill="#0000ff">B</tspan>
          </text>
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
      final redPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 170 && g < 120 && b < 120 && a > 200,
      );
      final bluePixels = _countPixels(
        pixels,
        (r, g, b, a) => b > 170 && r < 120 && g < 120 && a > 200,
      );

      expect(redPixels, greaterThan(300));
      expect(bluePixels, greaterThan(300));
    });

    testWidgets('renders textPath content on referenced path', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <path id="curve" d="M10,70 C30,10 70,10 90,70"/>
          </defs>
          <text font-size="14" fill="#ff0000">
            <textPath href="#curve">TEXT PATH</textPath>
          </text>
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
      final redPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 170 && g < 120 && b < 120 && a > 200,
      );

      expect(redPixels, greaterThan(600));
    });

    testWidgets('renders image element from data URI', (
      WidgetTester tester,
    ) async {
      final traces = <SvgTraceEvent>[];
      final svgXml =
          '''
        <svg viewBox="0 0 100 100">
          <image href="data:image/png;base64,$_tinyBluePngBase64" x="20" y="20" width="40" height="40"/>
        </svg>
      ''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              onTrace: traces.add,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      final imageProblems = traces
          .where((event) => event.category == 'image')
          .where((event) => event.level != SvgTraceLevel.info)
          .map((event) => event.message)
          .toList();
      expect(imageProblems, isEmpty, reason: imageProblems.join(' | '));
      expect(
        traces.any(
          (event) =>
              event.category == 'image' && event.message == 'Image decoded',
        ),
        isTrue,
        reason: traces
            .map(
              (event) =>
                  '${event.category}:${event.level.name}:${event.message}',
            )
            .join(' | '),
      );

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final bluePixels = _countPixels(
        pixels,
        (r, g, b, a) => b > 170 && r < 120 && g < 120 && a > 200,
      );

      expect(bluePixels, greaterThan(2500));
    });

    testWidgets('renders foreignObject viewport with translation and clipping', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject x="30" y="20" width="20" height="20">
            <rect x="0" y="0" width="40" height="40" fill="#ff0000"/>
          </foreignObject>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final analysis = VisualTestUtils.analyzeRedPixels(pixels, 800, 600);
      final inside = _pixelAt(pixels, width: 800, x: 80, y: 60);
      final clippedOut = _pixelAt(pixels, width: 800, x: 120, y: 60);

      // 20x20 SVG area => ~40x40 px после viewBox scale(2), с учетом anti-alias.
      expect(analysis.pixelCount, greaterThan(1100));
      expect(analysis.pixelCount, lessThan(2800));

      expect(inside.r, greaterThan(170));
      expect(inside.g, lessThan(120));
      expect(inside.b, lessThan(120));

      // Точка вне clipped viewport должна оставаться фоном.
      expect(clippedOut.r, greaterThan(220));
      expect(clippedOut.g, greaterThan(220));
      expect(clippedOut.b, greaterThan(220));
    });

    testWidgets('renders linear gradient fill', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <linearGradient id="lg" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stop-color="#ff0000"/>
              <stop offset="100%" stop-color="#0000ff"/>
            </linearGradient>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="url(#lg)"/>
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
      final redPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 170 && g < 120 && b < 120 && a > 200,
      );
      final bluePixels = _countPixels(
        pixels,
        (r, g, b, a) => b > 170 && r < 120 && g < 120 && a > 200,
      );

      expect(redPixels, greaterThan(1200));
      expect(bluePixels, greaterThan(1200));
    });

    testWidgets('renders radial gradient fill', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <radialGradient id="rg" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stop-color="#ffffff"/>
              <stop offset="100%" stop-color="#000000"/>
            </radialGradient>
          </defs>
          <circle cx="50" cy="50" r="35" fill="url(#rg)"/>
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
      final brightPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 220 && g > 220 && b > 220 && a > 200,
      );
      final darkPixels = _countPixels(
        pixels,
        (r, g, b, a) => r < 35 && g < 35 && b < 35 && a > 200,
      );

      expect(brightPixels, greaterThan(500));
      expect(darkPixels, greaterThan(500));
    });

    testWidgets('renders gradient stroke and respects fill none', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <linearGradient id="strokeGradient" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stop-color="#ff0000"/>
              <stop offset="100%" stop-color="#0000ff"/>
            </linearGradient>
          </defs>
          <rect
            x="10"
            y="10"
            width="80"
            height="80"
            fill="none"
            stroke="url(#strokeGradient)"
            stroke-width="8"/>
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
      final redPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 170 && g < 120 && b < 120 && a > 200,
      );
      final bluePixels = _countPixels(
        pixels,
        (r, g, b, a) => b > 170 && r < 120 && g < 120 && a > 200,
      );
      final center = _pixelAt(pixels, width: 800, x: 100, y: 100);

      expect(redPixels, greaterThan(600));
      expect(bluePixels, greaterThan(600));
      expect(center.r, greaterThan(220));
      expect(center.g, greaterThan(220));
      expect(center.b, greaterThan(220));
    });

    testWidgets('renders use references from defs only where used', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <circle id="dot" cx="10" cy="10" r="8" fill="red"/>
          </defs>
          <use href="#dot" x="20" y="20"/>
          <use href="#dot" x="60" y="20"/>
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

      // Two circles should be visible; defs content itself must not be painted.
      expect(analysis.pixelCount, greaterThan(1200));
      expect(analysis.pixelCount, lessThan(2200));
    });

    testWidgets('renders symbol via use with viewBox scaling', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="badge" viewBox="0 0 10 10">
              <circle cx="5" cy="5" r="5" fill="red"/>
            </symbol>
          </defs>
          <use href="#badge" x="20" y="20" width="40" height="40"/>
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

      expect(analysis.pixelCount, greaterThan(3500));
      expect(analysis.pixelCount, lessThan(7000));
    });

    testWidgets('renders symbol via use with preserveAspectRatio="none"', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="badge" viewBox="0 0 10 20" preserveAspectRatio="none">
              <rect x="0" y="0" width="10" height="20" fill="red"/>
            </symbol>
          </defs>
          <use href="#badge" x="20" y="20" width="40" height="40"/>
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

      // With preserveAspectRatio="none", 10x20 viewBox is stretched into 40x40.
      expect(analysis.objectWidth, greaterThan(65));
      expect(analysis.objectHeight, greaterThan(65));
      expect(
        (analysis.objectWidth - analysis.objectHeight).abs(),
        lessThan(10),
      );
    });

    testWidgets('renders nested svg via use with preserveAspectRatio="none"', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <svg id="badgeSvg" viewBox="0 0 10 20" preserveAspectRatio="none">
              <rect x="0" y="0" width="10" height="20" fill="red"/>
            </svg>
          </defs>
          <use href="#badgeSvg" x="20" y="20" width="40" height="40"/>
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

      expect(analysis.objectWidth, greaterThan(65));
      expect(analysis.objectHeight, greaterThan(65));
      expect(
        (analysis.objectWidth - analysis.objectHeight).abs(),
        lessThan(10),
      );
    });

    testWidgets('use inherits fill from use element into symbol subtree', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="badge" viewBox="0 0 10 10">
              <rect x="0" y="0" width="10" height="10"/>
            </symbol>
          </defs>
          <use href="#badge" x="20" y="20" width="40" height="40" fill="red"/>
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

      expect(analysis.pixelCount, greaterThan(3000));
    });

    testWidgets('use style fill overrides attribute on symbol subtree', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="badge" viewBox="0 0 10 10">
              <rect x="0" y="0" width="10" height="10"/>
            </symbol>
          </defs>
          <use
            href="#badge"
            x="20"
            y="20"
            width="40"
            height="40"
            fill="blue"
            style="fill:red"/>
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
      final redPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 170 && g < 120 && b < 120 && a > 200,
      );
      final bluePixels = _countPixels(
        pixels,
        (r, g, b, a) => b > 170 && r < 120 && g < 120 && a > 200,
      );

      expect(redPixels, greaterThan(3000));
      expect(bluePixels, lessThan(100));
    });

    testWidgets(
      'switch renders only first matching child by requiredFeatures',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <switch>
            <rect
              x="10"
              y="10"
              width="20"
              height="20"
              fill="blue"
              requiredFeatures="http://example.invalid/feature"/>
            <rect
              x="60"
              y="10"
              width="20"
              height="20"
              fill="red"/>
          </switch>
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
        final redPixels = _countPixels(
          pixels,
          (r, g, b, a) => r > 200 && g < 80 && b < 80 && a > 0,
        );
        final bluePixels = _countPixels(
          pixels,
          (r, g, b, a) => b > 200 && r < 80 && g < 80 && a > 0,
        );

        expect(redPixels, greaterThan(1200));
        expect(bluePixels, lessThan(100));
      },
    );

    testWidgets('use does not render disallowed foreignObject reference', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <foreignObject id="fo" x="0" y="0" width="30" height="30">
              <rect x="0" y="0" width="30" height="30" fill="red"/>
            </foreignObject>
          </defs>
          <use href="#fo" x="20" y="20"/>
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

      // Blink-style use expansion disallows foreignObject references.
      expect(analysis.pixelCount, lessThan(50));
    });

    testWidgets('applies clipPath to painted geometry', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipCircle">
              <circle cx="50" cy="50" r="20"/>
            </clipPath>
          </defs>
          <rect
            x="10"
            y="10"
            width="80"
            height="80"
            fill="red"
            clip-path="url(#clipCircle)"/>
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

      // Clipped by circle (scaled radius ~=40px), should be much smaller than full 80x80 rect.
      expect(analysis.pixelCount, greaterThan(3500));
      expect(analysis.pixelCount, lessThan(7000));
    });

    testWidgets('applies mask to painted geometry', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="maskCircle">
              <circle cx="50" cy="50" r="20" fill="white"/>
            </mask>
          </defs>
          <rect
            x="10"
            y="10"
            width="80"
            height="80"
            fill="red"
            mask="url(#maskCircle)"/>
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

      // Baseline geometry mask produces circle-like visible area.
      expect(analysis.pixelCount, greaterThan(3500));
      expect(analysis.pixelCount, lessThan(7000));
    });

    testWidgets('applies maskUnits objectBoundingBox to painted geometry', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="maskHalf" maskUnits="objectBoundingBox" x="0" y="0" width="0.5" height="1">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect
            x="10"
            y="10"
            width="80"
            height="80"
            fill="red"
            mask="url(#maskHalf)"/>
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

      // ObjectBoundingBox mask units should constrain visibility to half width.
      expect(analysis.pixelCount, greaterThan(2000));
      expect(analysis.objectWidth, lessThan(analysis.objectHeight * 0.75));
    });

    testWidgets(
      'applies maskUnits userSpaceOnUse percentage region to painted geometry',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask
              id="maskRightHalf"
              maskUnits="userSpaceOnUse"
              x="50%"
              y="0%"
              width="50%"
              height="100%">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect
            x="10"
            y="10"
            width="80"
            height="80"
            fill="red"
            mask="url(#maskRightHalf)"/>
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

        expect(analysis.pixelCount, greaterThan(2000));
        expect(analysis.objectWidth, lessThan(analysis.objectHeight * 0.75));
      },
    );

    testWidgets('applies feFlood as solid color filter', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="floodFx">
              <feFlood flood-color="#00ff00" flood-opacity="1"/>
            </filter>
          </defs>
          <rect
            x="10"
            y="10"
            width="80"
            height="80"
            fill="#ff0000"
            filter="url(#floodFx)"/>
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
      final greenPixels = _countPixels(
        pixels,
        (r, g, b, a) => g > 170 && r < 120 && b < 120 && a > 200,
      );
      final redPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 170 && g < 120 && b < 120 && a > 200,
      );

      expect(greenPixels, greaterThan(8000));
      expect(redPixels, lessThan(400));
    });

    testWidgets('applies feBlend multiply over backdrop', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="blendFx">
              <feBlend mode="multiply"/>
            </filter>
          </defs>
          <rect x="0" y="0" width="100" height="100" fill="#ffff00"/>
          <rect
            x="20"
            y="20"
            width="60"
            height="60"
            fill="#0000ff"
            filter="url(#blendFx)"/>
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
      final center = _pixelAt(pixels, width: 800, x: 100, y: 100);
      final corner = _pixelAt(pixels, width: 800, x: 20, y: 20);

      // Center lies in blend overlap area, multiply(blue, yellow) ~= black.
      expect(center.r, lessThan(40));
      expect(center.g, lessThan(40));
      expect(center.b, lessThan(40));
      // Corner remains yellow backdrop.
      expect(corner.r, greaterThan(220));
      expect(corner.g, greaterThan(220));
      expect(corner.b, lessThan(60));
    });

    testWidgets('applies feComposite xor over backdrop', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="compFx">
              <feComposite operator="xor"/>
            </filter>
          </defs>
          <rect x="10" y="10" width="80" height="80" fill="#00ff00"/>
          <rect
            x="30"
            y="30"
            width="60"
            height="60"
            fill="#0000ff"
            filter="url(#compFx)"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      );

      await tester.pump();

      final pixels = await VisualTestUtils.captureWidgetPixels(tester);
      final overlapCenter = _pixelAt(pixels, width: 800, x: 120, y: 120);
      final greenOnly = _pixelAt(pixels, width: 800, x: 40, y: 40);

      // XOR removes opaque overlap area => transparent hole in layer buffer.
      expect(overlapCenter.a, lessThan(20));
      // Area outside overlap remains green.
      expect(greenOnly.g, greaterThan(170));
      expect(greenOnly.r, lessThan(120));
      expect(greenOnly.b, lessThan(120));
    });

    testWidgets('parses feMerge filter and keeps source rendering baseline', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="mergeFx">
              <feMerge>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <rect
            x="10"
            y="10"
            width="80"
            height="80"
            fill="#0000ff"
            filter="url(#mergeFx)"/>
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
      final bluePixels = _countPixels(
        pixels,
        (r, g, b, a) => b > 170 && r < 120 && g < 120 && a > 200,
      );

      expect(bluePixels, greaterThan(8000));
    });

    testWidgets('renders feDropShadow with source + shadow composition', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="shadowFx">
              <feDropShadow
                dx="8"
                dy="8"
                stdDeviation="3"
                flood-color="#000000"
                flood-opacity="1"/>
            </filter>
          </defs>
          <rect
            x="20"
            y="20"
            width="30"
            height="30"
            fill="#ff0000"
            filter="url(#shadowFx)"/>
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
      final redPixels = _countPixels(
        pixels,
        (r, g, b, a) => r > 170 && g < 120 && b < 120 && a > 160,
      );
      final shadowPixels = _countPixels(
        pixels,
        (r, g, b, a) => r < 90 && g < 90 && b < 90 && a > 40,
      );

      // Источник должен оставаться заметно красным.
      expect(redPixels, greaterThan(2500));
      // Должно появляться значимое количество темных shadow-пикселей.
      expect(shadowPixels, greaterThan(300));
    });

    testWidgets('renders feMerge with blurred result and source graphic', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <filter id="mergeBlurFx">
              <feGaussianBlur stdDeviation="3" result="blurred"/>
              <feMerge>
                <feMergeNode in="blurred"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>
          <rect
            x="20"
            y="20"
            width="30"
            height="30"
            fill="#0000ff"
            filter="url(#mergeBlurFx)"/>
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
      final outsideBlur = _pixelAt(pixels, width: 800, x: 70, y: 70);
      final center = _pixelAt(pixels, width: 800, x: 90, y: 90);

      // Центр источника остается ярко-синим.
      expect(center.b, greaterThan(170));
      expect(center.r, lessThan(120));
      expect(center.g, lessThan(120));

      // Вне исходной геометрии ожидаем синий blur-хвост от merge(blurred + source).
      expect(outsideBlur.b, greaterThan(30));
      expect(outsideBlur.a, greaterThan(20));
    });

    testWidgets('animates opacity', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" fill="blue">
            <animate attributeName="opacity" from="1" to="0" dur="1s"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('handles repeatCount indefinite', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="0" y="0" width="20" height="20" fill="red">
            <animate attributeName="x" from="0" to="80" dur="1s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      // Несколько циклов анимации
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('applies backgroundColor', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="20" height="20" fill="red"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('handles viewBox scaling', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 50 50">
          <rect x="5" y="5" width="40" height="40" fill="purple"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders stroke', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" 
                fill="none" stroke="black" stroke-width="2"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders line', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <line x1="10" y1="10" x2="90" y2="90" stroke="red" stroke-width="3"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('renders rounded rect', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" rx="10" ry="10" fill="orange"/>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(svgXml, width: 200, height: 200),
          ),
        ),
      );

      expect(find.byType(AnimatedSvgPicture), findsOneWidget);
    });

    testWidgets('animates fill color', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="10" y="10" width="80" height="80" fill="red">
            <animate attributeName="fill" from="red" to="blue" dur="1s" repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('animates stroke color', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="30" fill="none" stroke="green" stroke-width="3">
            <animate attributeName="stroke" from="#00ff00" to="#ff0000" dur="2s" repeatCount="indefinite"/>
          </circle>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('animates transform rotate', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect x="40" y="40" width="20" height="20" fill="red">
            <animateTransform
              attributeName="transform"
              type="rotate"
              from="0 50 50"
              to="360 50 50"
              dur="2s"
              repeatCount="indefinite"/>
          </rect>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('animates transform translate', (WidgetTester tester) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <circle cx="20" cy="50" r="10" fill="blue">
            <animateTransform
              attributeName="transform"
              type="translate"
              from="0 0"
              to="60 0"
              dur="1s"
              repeatCount="indefinite"/>
          </circle>
        </svg>
      ''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedSvgPicture.string(
              svgXml,
              width: 200,
              height: 200,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('element-specific click triggers targeted animation only', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="target" x="10" y="10" width="20" height="20" fill="blue"/>
          <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Клик вне target элемента не должен запускать target.click анимацию
      await tester.tapAt(topLeft + const Offset(170, 170));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;

      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Клик по target должен запустить анимацию moving элемента
      await tester.tapAt(topLeft + const Offset(40, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets(
      'use-referenced target click triggers targeted animation only',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="target" x="10" y="10" width="20" height="20" fill="blue"/>
          </defs>
          <use href="#target"/>
          <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(170, 170));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
          outsidePixels,
          800,
          600,
        );
        final outsideCentroid = outsideAnalysis.centroid;
        expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

        await tester.tapAt(topLeft + const Offset(40, 40));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final targetAnalysis = VisualTestUtils.analyzeRedPixels(
          targetPixels,
          800,
          600,
        );
        final targetCentroid = targetAnalysis.centroid;

        expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
      },
    );

    testWidgets('switch hit-testing resolves only active branch', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <switch>
            <rect
              id="blocked"
              x="10"
              y="10"
              width="20"
              height="20"
              fill="blue"
              requiredFeatures="http://example.invalid/feature"/>
            <rect
              id="target"
              x="60"
              y="10"
              width="20"
              height="20"
              fill="blue"/>
          </switch>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      await tester.tapAt(topLeft + const Offset(40, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final blockedPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final blockedAnalysis = VisualTestUtils.analyzeRedPixels(
        blockedPixels,
        800,
        600,
      );
      final blockedCentroid = blockedAnalysis.centroid;
      expect((blockedCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      await tester.tapAt(topLeft + const Offset(140, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;
      expect(targetCentroid.dx, greaterThan(blockedCentroid.dx + 5));
    });

    testWidgets('clipPath use geometry gates hit-testing', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="clipRect" x="10" y="10" width="20" height="20"/>
            <clipPath id="clipFromUse">
              <use href="#clipRect"/>
            </clipPath>
          </defs>
          <rect
            id="target"
            x="10"
            y="10"
            width="40"
            height="40"
            fill="blue"
            clip-path="url(#clipFromUse)"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      await tester.tapAt(topLeft + const Offset(80, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      await tester.tapAt(topLeft + const Offset(40, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;
      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('mask use geometry gates hit-testing', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <rect id="maskRect" x="10" y="10" width="20" height="20" fill="white"/>
            <mask id="maskFromUse">
              <use href="#maskRect"/>
            </mask>
          </defs>
          <rect
            id="target"
            x="10"
            y="10"
            width="40"
            height="40"
            fill="blue"
            mask="url(#maskFromUse)"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      await tester.tapAt(topLeft + const Offset(80, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      await tester.tapAt(topLeft + const Offset(40, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;
      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets(
      'use fill none disables hit-testing for inherited fill target',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="badge" viewBox="0 0 10 10">
              <rect id="target" x="0" y="0" width="10" height="10"/>
            </symbol>
          </defs>
          <use href="#badge" x="20" y="20" width="40" height="40" fill="none"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(80, 80));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));
      },
    );

    testWidgets(
      'use style fill none disables hit-testing over attribute fill',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="badge" viewBox="0 0 10 10">
              <rect id="target" x="0" y="0" width="10" height="10"/>
            </symbol>
          </defs>
          <use
            href="#badge"
            x="20"
            y="20"
            width="40"
            height="40"
            fill="blue"
            style="fill:none"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(80, 80));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));
      },
    );

    testWidgets('symbol use with slice clips hit-testing to use viewport', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <symbol id="badge" viewBox="0 0 10 20" preserveAspectRatio="xMidYMid slice">
              <rect id="target" x="0" y="0" width="10" height="20" fill="blue"/>
            </symbol>
          </defs>
          <use href="#badge" x="20" y="20" width="40" height="40"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Inside expanded symbol geometry but outside clipped <use> viewport.
      await tester.tapAt(topLeft + const Offset(80, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Inside clipped <use> viewport.
      await tester.tapAt(topLeft + const Offset(80, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('svg use with slice clips hit-testing to use viewport', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <svg id="badgeSvg" viewBox="0 0 10 20" preserveAspectRatio="xMidYMid slice">
              <rect id="target" x="0" y="0" width="10" height="20" fill="blue"/>
            </svg>
          </defs>
          <use href="#badgeSvg" x="20" y="20" width="40" height="40"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      await tester.tapAt(topLeft + const Offset(80, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      await tester.tapAt(topLeft + const Offset(80, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets(
      'use of foreignObject does not trigger target click animations',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <foreignObject id="target" x="10" y="10" width="20" height="20">
              <rect x="0" y="0" width="20" height="20" fill="blue"/>
            </foreignObject>
          </defs>
          <use href="#target"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(40, 40));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final afterPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final afterAnalysis = VisualTestUtils.analyzeRedPixels(
          afterPixels,
          800,
          600,
        );
        final afterCentroid = afterAnalysis.centroid;

        expect((afterCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));
      },
    );

    testWidgets('clipPath-aware click respects clipped hit region', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipCircle">
              <circle cx="20" cy="20" r="10"/>
            </clipPath>
          </defs>
          <rect id="target" x="10" y="10" width="20" height="20" fill="blue" clip-path="url(#clipCircle)"/>
          <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Inside original rect but outside clipped circle.
      await tester.tapAt(topLeft + const Offset(22, 22));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Inside clipped circle.
      await tester.tapAt(topLeft + const Offset(40, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('clipPathUnits objectBoundingBox gates click hit region', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <clipPath id="clipHalf" clipPathUnits="objectBoundingBox">
              <rect x="0" y="0" width="0.5" height="1"/>
            </clipPath>
          </defs>
          <rect id="target" x="20" y="20" width="40" height="40" fill="blue" clip-path="url(#clipHalf)"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Right half of target rect, clipped out by objectBoundingBox clip.
      await tester.tapAt(topLeft + const Offset(110, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Left half of target rect, inside clipped area.
      await tester.tapAt(topLeft + const Offset(60, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('maskContentUnits objectBoundingBox gates click hit region', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask id="maskHalf" maskContentUnits="objectBoundingBox">
              <rect x="0" y="0" width="0.5" height="1" fill="white"/>
            </mask>
          </defs>
          <rect id="target" x="20" y="20" width="40" height="40" fill="blue" mask="url(#maskHalf)"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Right half of target rect, clipped out by objectBoundingBox mask.
      await tester.tapAt(topLeft + const Offset(110, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Left half of target rect, inside masked area.
      await tester.tapAt(topLeft + const Offset(60, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('maskUnits objectBoundingBox gates click hit region', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask
              id="maskRegionHalf"
              maskUnits="objectBoundingBox"
              x="0"
              y="0"
              width="0.5"
              height="1">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect id="target" x="20" y="20" width="40" height="40" fill="blue" mask="url(#maskRegionHalf)"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Right half of target rect, outside maskUnits region.
      await tester.tapAt(topLeft + const Offset(110, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Left half of target rect, inside maskUnits region.
      await tester.tapAt(topLeft + const Offset(60, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('maskUnits userSpaceOnUse percentages gate click hit region', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <mask
              id="maskRightHalfHit"
              maskUnits="userSpaceOnUse"
              x="50%"
              y="0%"
              width="50%"
              height="100%">
              <rect x="0" y="0" width="100" height="100" fill="white"/>
            </mask>
          </defs>
          <rect id="target" x="20" y="20" width="40" height="40" fill="blue" mask="url(#maskRightHalfHit)"/>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Left part of target, outside x=50% mask region.
      await tester.tapAt(topLeft + const Offset(70, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Right part of target, inside x=50% mask region.
      await tester.tapAt(topLeft + const Offset(110, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('polygon target click triggers targeted animation only', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <polygon id="target" points="10,10 35,10 22.5,35" fill="blue"/>
          <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Outside polygon: animation should not start.
      await tester.tapAt(topLeft + const Offset(170, 170));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Inside polygon target.
      await tester.tapAt(topLeft + const Offset(45, 45));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('path target click triggers targeted animation only', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <path id="target" d="M10 10 L35 10 L22.5 35 Z" fill="blue"/>
          <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      // Outside path: animation should not start.
      await tester.tapAt(topLeft + const Offset(170, 170));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      // Inside path target.
      await tester.tapAt(topLeft + const Offset(45, 45));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('text target click triggers targeted animation only', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <text id="label" x="10" y="30" font-size="20" fill="blue">GO</text>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="label.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      await tester.tapAt(topLeft + const Offset(170, 170));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      await tester.tapAt(topLeft + const Offset(42, 58));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets(
      'tspan target click uses rendered cursor position from previous sibling',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <text x="10" y="30" font-size="16" fill="blue">
            <tspan>AAAA</tspan>
            <tspan id="target">B</tspan>
          </text>
          <rect id="moving" x="10" y="70" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        final firstPainter = TextPainter(
          text: const TextSpan(text: 'AAAA', style: TextStyle(fontSize: 16)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final secondPainter = TextPainter(
          text: const TextSpan(text: 'B', style: TextStyle(fontSize: 16)),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final baseline = firstPainter.computeDistanceToActualBaseline(
          TextBaseline.alphabetic,
        );
        final localCenterY = 30.0 - baseline + firstPainter.height / 2;
        final firstCenterLocalX = 10.0 + firstPainter.width / 2;
        final secondCenterLocalX =
            10.0 + firstPainter.width + secondPainter.width / 2;

        // Click inside first tspan run: should not trigger target='B'.
        await tester.tapAt(
          topLeft + Offset(firstCenterLocalX * 2, localCenterY * 2),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
          outsidePixels,
          800,
          600,
        );
        final outsideCentroid = outsideAnalysis.centroid;
        expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

        // Click second tspan glyph ('B'): should trigger.
        await tester.tapAt(
          topLeft + Offset(secondCenterLocalX * 2, localCenterY * 2),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final targetAnalysis = VisualTestUtils.analyzeRedPixels(
          targetPixels,
          800,
          600,
        );
        final targetCentroid = targetAnalysis.centroid;

        expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
      },
    );

    testWidgets(
      'textPath startOffset gates hit-testing to rendered text segment',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <path id="curve" d="M10,50 L90,50"/>
          </defs>
          <text font-size="16" fill="blue">
            <textPath id="target" href="#curve" startOffset="75%">GO</textPath>
          </text>
          <rect id="moving" x="10" y="80" width="15" height="15" fill="red">
            <animate attributeName="x" from="10" to="75" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        // Near path start but before rendered text startOffset segment.
        await tester.tapAt(topLeft + const Offset(40, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
          outsidePixels,
          800,
          600,
        );
        final outsideCentroid = outsideAnalysis.centroid;
        expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

        // Inside rendered text segment near path end.
        await tester.tapAt(topLeft + const Offset(160, 100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final targetAnalysis = VisualTestUtils.analyzeRedPixels(
          targetPixels,
          800,
          600,
        );
        final targetCentroid = targetAnalysis.centroid;

        expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
      },
    );

    testWidgets('textPath target click triggers targeted animation only', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <defs>
            <path id="curve" d="M10,70 C30,10 70,10 90,70"/>
          </defs>
          <text id="label" font-size="14" fill="blue">
            <textPath href="#curve">GO PATH</textPath>
          </text>
          <rect id="moving" x="10" y="80" width="15" height="15" fill="red">
            <animate attributeName="x" from="10" to="75" dur="1s" begin="label.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      await tester.tapAt(topLeft + const Offset(170, 170));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(3));

      await tester.tapAt(topLeft + const Offset(20, 140));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets('image target click triggers targeted animation only', (
      WidgetTester tester,
    ) async {
      final svgXml =
          '''
        <svg viewBox="0 0 100 100">
          <image id="target" href="data:image/png;base64,$_tinyBluePngBase64" x="10" y="10" width="20" height="20"/>
          <rect id="moving" x="10" y="80" width="15" height="15" fill="red">
            <animate attributeName="x" from="10" to="75" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                autoPlay: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
        beforePixels,
        800,
        600,
      );
      final beforeCentroid = beforeAnalysis.centroid;

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      await tester.tapAt(topLeft + const Offset(170, 170));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
      final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
        outsidePixels,
        800,
        600,
      );
      final outsideCentroid = outsideAnalysis.centroid;
      expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(4));

      await tester.tapAt(topLeft + const Offset(40, 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
      final targetAnalysis = VisualTestUtils.analyzeRedPixels(
        targetPixels,
        800,
        600,
      );
      final targetCentroid = targetAnalysis.centroid;

      expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
    });

    testWidgets(
      'foreignObject child target click triggers targeted animation only',
      (WidgetTester tester) async {
        const svgXml = '''
        <svg viewBox="0 0 100 100">
          <foreignObject x="20" y="20" width="20" height="20">
            <rect id="target" x="0" y="0" width="20" height="20" fill="blue"/>
          </foreignObject>
          <rect id="moving" x="10" y="80" width="15" height="15" fill="red">
            <animate attributeName="x" from="10" to="75" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
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
                  autoPlay: true,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final beforePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final beforeAnalysis = VisualTestUtils.analyzeRedPixels(
          beforePixels,
          800,
          600,
        );
        final beforeCentroid = beforeAnalysis.centroid;

        final pictureFinder = find.byType(AnimatedSvgPicture);
        final topLeft = tester.getTopLeft(pictureFinder);

        await tester.tapAt(topLeft + const Offset(170, 170));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final outsidePixels = await VisualTestUtils.captureWidgetPixels(tester);
        final outsideAnalysis = VisualTestUtils.analyzeRedPixels(
          outsidePixels,
          800,
          600,
        );
        final outsideCentroid = outsideAnalysis.centroid;
        expect((outsideCentroid.dx - beforeCentroid.dx).abs(), lessThan(4));

        // foreignObject(x=20,y=20,w=20,h=20) => target виден примерно в зоне 40..80 px.
        await tester.tapAt(topLeft + const Offset(60, 60));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final targetPixels = await VisualTestUtils.captureWidgetPixels(tester);
        final targetAnalysis = VisualTestUtils.analyzeRedPixels(
          targetPixels,
          800,
          600,
        );
        final targetCentroid = targetAnalysis.centroid;

        expect(targetCentroid.dx, greaterThan(outsideCentroid.dx + 5));
      },
    );

    testWidgets('emits trace events for init and tap target', (
      WidgetTester tester,
    ) async {
      const svgXml = '''
        <svg viewBox="0 0 100 100">
          <rect id="target" x="10" y="10" width="20" height="20" fill="blue"/>
          <rect id="moving" x="10" y="60" width="20" height="20" fill="red">
            <animate attributeName="x" from="10" to="70" dur="1s" begin="target.click" fill="freeze"/>
          </rect>
        </svg>
      ''';

      final traces = <SvgTraceEvent>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedSvgPicture.string(
                svgXml,
                width: 200,
                height: 200,
                autoPlay: true,
                onTrace: traces.add,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(
        traces.any(
          (event) =>
              event.category == 'init' &&
              event.message == 'SVG parsed successfully',
        ),
        isTrue,
      );

      final pictureFinder = find.byType(AnimatedSvgPicture);
      final topLeft = tester.getTopLeft(pictureFinder);

      await tester.tapAt(topLeft + const Offset(40, 40));
      await tester.pump();

      final tapTrace = traces.lastWhere(
        (event) => event.category == 'event' && event.message == 'Tap detected',
      );
      expect(tapTrace.data['targetId'], equals('target'));
    });
  });
}

int _countPixels(
  Uint8List pixels,
  bool Function(int r, int g, int b, int a) predicate,
) {
  int count = 0;
  for (int i = 0; i + 3 < pixels.length; i += 4) {
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    final a = pixels[i + 3];
    if (predicate(r, g, b, a)) {
      count++;
    }
  }
  return count;
}

_Rgba _pixelAt(
  Uint8List pixels, {
  required int width,
  required int x,
  required int y,
}) {
  final index = (y * width + x) * 4;
  return _Rgba(
    r: pixels[index],
    g: pixels[index + 1],
    b: pixels[index + 2],
    a: pixels[index + 3],
  );
}

class _Rgba {
  const _Rgba({
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  });

  final int r;
  final int g;
  final int b;
  final int a;
}
