import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'visual_test_utils.dart';

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
