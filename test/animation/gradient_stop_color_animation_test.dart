import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/src/animation/animated_svg_painter.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';

void main() {
  group('Gradient stop-color animation via CSS selectors', () {
    test('CSS ID selector targets stop element inside radialGradient', () {
      // This pattern is used by SVGator - CSS ID selectors target stop elements
      const svgString = '''
<svg viewBox="0 0 700 400">
  <style>
    #stop1 {animation: colorAnim 3000ms linear infinite;}
    @keyframes colorAnim { 
      0% {stop-color: #56fea5} 
      50% {stop-color: #d9ff52} 
      100% {stop-color: #56fea5}
    }
  </style>
  <defs>
    <radialGradient id="grad1" cx="0" cy="0" r="0.5" 
                    gradientUnits="userSpaceOnUse"
                    gradientTransform="matrix(1158 0 0 1158 488 500)">
      <stop id="stop1" offset="0%" stop-color="#56fea5"/>
      <stop id="stop2" offset="100%" stop-color="#d9ff52"/>
    </radialGradient>
  </defs>
  <rect width="700" height="400" fill="url(#grad1)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should find stop-color animation targeting stop1
      final stopColorAnims = animations
          .where((a) => a.attributeName == 'stop-color')
          .toList();

      expect(
        stopColorAnims,
        isNotEmpty,
        reason: 'Expected stop-color animation from CSS ID selector',
      );

      // Verify the animation targets the correct stop element
      final anim = stopColorAnims.first;
      expect(anim.targetNode.id, equals('stop1'));
      expect(anim.attributeType, equals(SvgAttributeType.color));
    });

    test('CSS ID selector stop-color animation updates values correctly', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    #stop1 {animation: colorAnim 2s linear forwards;}
    @keyframes colorAnim { 
      0% {stop-color: #ff0000} 
      100% {stop-color: #00ff00}
    }
  </style>
  <defs>
    <linearGradient id="grad1">
      <stop id="stop1" offset="0%" stop-color="#ff0000"/>
      <stop offset="100%" stop-color="#0000ff"/>
    </linearGradient>
  </defs>
  <rect width="100" height="100" fill="url(#grad1)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final anim = animations.firstWhere(
        (a) => a.attributeName == 'stop-color',
      );

      // At t=0 should be red
      anim.updateForTime(Duration.zero);
      final colorAt0 = anim.targetNode.getAttributeValue('stop-color');
      expect(colorAt0, isA<ui.Color>());
      final c0 = colorAt0 as ui.Color;
      expect(
        (c0.r * 255).round(),
        greaterThan(200),
        reason: 'Red should be dominant at t=0',
      );

      // At t=2s should be green
      anim.updateForTime(const Duration(seconds: 2));
      final colorAt2 = anim.targetNode.getAttributeValue('stop-color');
      expect(colorAt2, isA<ui.Color>());
      final c2 = colorAt2 as ui.Color;
      expect(
        (c2.g * 255).round(),
        greaterThan(200),
        reason: 'Green should be dominant at t=2s',
      );
    });

    test('Multiple stop elements with CSS selector animations', () {
      // Tests the exact pattern from astronaut_helmet.svg
      const svgString = '''
<svg viewBox="0 0 700 400">
  <style>
    #eQVNhIKm4qz3-fill-0 {animation: eQVNhIKm4qz3-fill-0__c 3000ms linear infinite normal forwards}
    @keyframes eQVNhIKm4qz3-fill-0__c { 0% {stop-color: #56fea5} 50% {stop-color: #d9ff52} 100% {stop-color: #56fea5}}
    #eQVNhIKm4qz3-fill-1 {animation: eQVNhIKm4qz3-fill-1__c 3000ms linear infinite normal forwards}
    @keyframes eQVNhIKm4qz3-fill-1__c { 0% {stop-color: #d9ff52} 50% {stop-color: #56fea5} 100% {stop-color: #d9ff52}}
  </style>
  <defs>
    <radialGradient id="eQVNhIKm4qz3-fill" cx="0" cy="0" r="0.5" 
                    spreadMethod="pad" gradientUnits="userSpaceOnUse" 
                    gradientTransform="matrix(1158.649672 0 0 1158.649672 488.314258 500)">
      <stop id="eQVNhIKm4qz3-fill-0" offset="0%" stop-color="#56fea5"/>
      <stop id="eQVNhIKm4qz3-fill-1" offset="100%" stop-color="#d9ff52"/>
    </radialGradient>
  </defs>
  <rect width="700" height="520" fill="url(#eQVNhIKm4qz3-fill)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Should find both stop-color animations
      final stopColorAnims = animations
          .where((a) => a.attributeName == 'stop-color')
          .toList();

      expect(
        stopColorAnims.length,
        equals(2),
        reason: 'Expected 2 stop-color animations (one per stop)',
      );

      // Verify both stop elements are targeted
      final targetIds = stopColorAnims.map((a) => a.targetNode.id).toSet();
      expect(targetIds, contains('eQVNhIKm4qz3-fill-0'));
      expect(targetIds, contains('eQVNhIKm4qz3-fill-1'));
    });

    test(
      'CSS selector stop-color animation gets animated value at paint time',
      () {
        const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    #stop1 {animation: colorAnim 2s linear forwards;}
    @keyframes colorAnim { 
      0% {stop-color: #ff0000} 
      100% {stop-color: #00ff00}
    }
  </style>
  <defs>
    <linearGradient id="grad1">
      <stop id="stop1" offset="0%" stop-color="#ff0000"/>
      <stop offset="100%" stop-color="#0000ff"/>
    </linearGradient>
  </defs>
  <rect width="100" height="100" fill="url(#grad1)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        // Get the stop element
        final stopNode = document.root.findById('stop1');
        expect(stopNode, isNotNull);

        // Update animation to midpoint
        final anim = animations.firstWhere(
          (a) => a.attributeName == 'stop-color',
        );
        anim.updateForTime(const Duration(seconds: 1));

        // Verify the stop element has animated value
        final animatedColor = stopNode!.getAttributeValue('stop-color');
        expect(animatedColor, isA<ui.Color>());

        // At 50%, should be interpolated (orange/yellow-ish)
        final color = animatedColor as ui.Color;
        final r = (color.r * 255).round();
        final g = (color.g * 255).round();
        // At midpoint of red->green, expect ~128 for both R and G
        expect(
          r,
          inInclusiveRange(100, 160),
          reason: 'Red should be ~127 at midpoint',
        );
        expect(
          g,
          inInclusiveRange(100, 160),
          reason: 'Green should be ~127 at midpoint',
        );
      },
    );
  });

  group('Gradient shader with animated stop colors', () {
    test('radialGradient with userSpaceOnUse and small radius works', () {
      // This tests the specific parameters from astronaut_helmet.svg
      // The gradient has cx=0, cy=0, r=0.5 in userSpaceOnUse with a transform
      const svgString = '''
<svg viewBox="0 0 700 400">
  <defs>
    <radialGradient id="grad1" cx="0" cy="0" r="0.5" 
                    gradientUnits="userSpaceOnUse"
                    gradientTransform="matrix(1158.649672 0 0 1158.649672 488.314258 500)">
      <stop offset="0%" stop-color="#56fea5"/>
      <stop offset="100%" stop-color="#d9ff52"/>
    </radialGradient>
  </defs>
  <rect width="700" height="400" fill="url(#grad1)"/>
</svg>
''';

      // Just verify it parses without errors
      final document = SvgParser.parse(svgString);
      expect(document, isNotNull);

      // Find the gradient
      final grad = document.root.findById('grad1');
      expect(grad, isNotNull);
      expect(grad!.tagName, equals('radialGradient'));

      // Verify gradient attributes are parsed correctly
      expect(grad.getAttributeValue('cx'), equals(0.0));
      expect(grad.getAttributeValue('cy'), equals(0.0));
      expect(grad.getAttributeValue('r'), equals(0.5));
      expect(grad.getAttributeValue('gradientUnits'), equals('userSpaceOnUse'));
    });

    test('stop element in gradient has animated value accessible by parent', () {
      // Test that when we traverse gradient children at paint time,
      // we see the animated stop-color values
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    #stop1 {animation: colorAnim 2s linear forwards;}
    @keyframes colorAnim { 
      0% {stop-color: #ff0000} 
      100% {stop-color: #00ff00}
    }
  </style>
  <defs>
    <linearGradient id="grad1">
      <stop id="stop1" offset="0%" stop-color="#ff0000"/>
      <stop offset="100%" stop-color="#0000ff"/>
    </linearGradient>
  </defs>
  <rect width="100" height="100" fill="url(#grad1)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Update animation to midpoint
      final anim = animations.firstWhere(
        (a) => a.attributeName == 'stop-color',
      );
      anim.updateForTime(const Duration(seconds: 1));

      // Now find the gradient and iterate its children (like _parseGradientStops does)
      final gradient = document.root.findById('grad1');
      expect(gradient, isNotNull);

      for (final child in gradient!.children) {
        if (child.tagName == 'stop' && child.id == 'stop1') {
          // This is what _parseGradientStops does:
          final stopColorValue = child.getAttributeValue('stop-color');
          expect(stopColorValue, isA<ui.Color>());

          final color = stopColorValue as ui.Color;
          final r = (color.r * 255).round();
          final g = (color.g * 255).round();

          // At midpoint, should be interpolated
          expect(
            r,
            inInclusiveRange(100, 160),
            reason: 'Red should be ~127 at midpoint, got $r',
          );
          expect(
            g,
            inInclusiveRange(100, 160),
            reason: 'Green should be ~127 at midpoint, got $g',
          );
        }
      }
    });

    test('AnimatedSvgPainter creates gradient shader for url(#id) fill', () {
      // Test the exact astronaut helmet SVG pattern
      const svgString = '''
<svg viewBox="0 0 700 400">
  <style>
    #eQVNhIKm4qz3-fill-0 {animation: eQVNhIKm4qz3-fill-0__c 3000ms linear infinite normal forwards}
    @keyframes eQVNhIKm4qz3-fill-0__c { 0% {stop-color: #56fea5} 50% {stop-color: #d9ff52} 100% {stop-color: #56fea5}}
    #eQVNhIKm4qz3-fill-1 {animation: eQVNhIKm4qz3-fill-1__c 3000ms linear infinite normal forwards}
    @keyframes eQVNhIKm4qz3-fill-1__c { 0% {stop-color: #d9ff52} 50% {stop-color: #56fea5} 100% {stop-color: #d9ff52}}
  </style>
  <defs>
    <radialGradient id="eQVNhIKm4qz3-fill" cx="0" cy="0" r="0.5" 
                    spreadMethod="pad" gradientUnits="userSpaceOnUse" 
                    gradientTransform="matrix(1158.649672 0 0 1158.649672 488.314258 500)">
      <stop id="eQVNhIKm4qz3-fill-0" offset="0%" stop-color="#56fea5"/>
      <stop id="eQVNhIKm4qz3-fill-1" offset="100%" stop-color="#d9ff52"/>
    </radialGradient>
  </defs>
  <rect id="eQVNhIKm4qz3" width="700" height="520" fill="url(#eQVNhIKm4qz3-fill)" stroke-width="0"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      // Verify animations were found
      expect(
        animations.where((a) => a.attributeName == 'stop-color').length,
        equals(2),
        reason: 'Expected 2 stop-color animations',
      );

      // Create the painter (verifies no error during construction)
      // ignore: unused_local_variable
      final painter = AnimatedSvgPainter(
        document: document,
        hasAnimations: true,
      );

      // Verify the rect element has the correct fill
      final rect = document.root.findById('eQVNhIKm4qz3');
      expect(rect, isNotNull);
      expect(
        rect!.getAttributeValue('fill'),
        equals('url(#eQVNhIKm4qz3-fill)'),
      );

      // Verify the gradient exists and has stops
      final gradient = document.root.findById('eQVNhIKm4qz3-fill');
      expect(gradient, isNotNull);
      expect(gradient!.tagName, equals('radialGradient'));
      expect(gradient.children.length, equals(2));

      // Verify gradient attributes
      expect(
        gradient.getAttributeValue('r'),
        equals(0.5),
        reason: 'Radius should be 0.5 (userSpaceOnUse, absolute value)',
      );
      expect(
        gradient.getAttributeValue('gradientUnits'),
        equals('userSpaceOnUse'),
      );

      // Verify gradientTransform is present
      expect(gradient.getAttributeValue('gradientTransform'), isNotNull);
    });

    testWidgets(
      'radialGradient with userSpaceOnUse and gradientTransform renders',
      (tester) async {
        // Test the exact astronaut helmet pattern with widget rendering
        const svgString = '''
<svg viewBox="0 0 700 400">
  <style>
    #eQVNhIKm4qz3-fill-0 {animation: eQVNhIKm4qz3-fill-0__c 3000ms linear infinite normal forwards}
    @keyframes eQVNhIKm4qz3-fill-0__c { 0% {stop-color: #56fea5} 50% {stop-color: #d9ff52} 100% {stop-color: #56fea5}}
    #eQVNhIKm4qz3-fill-1 {animation: eQVNhIKm4qz3-fill-1__c 3000ms linear infinite normal forwards}
    @keyframes eQVNhIKm4qz3-fill-1__c { 0% {stop-color: #d9ff52} 50% {stop-color: #56fea5} 100% {stop-color: #d9ff52}}
  </style>
  <defs>
    <radialGradient id="eQVNhIKm4qz3-fill" cx="0" cy="0" r="0.5" 
                    spreadMethod="pad" gradientUnits="userSpaceOnUse" 
                    gradientTransform="matrix(1158.649672 0 0 1158.649672 488.314258 500)">
      <stop id="eQVNhIKm4qz3-fill-0" offset="0%" stop-color="#56fea5"/>
      <stop id="eQVNhIKm4qz3-fill-1" offset="100%" stop-color="#d9ff52"/>
    </radialGradient>
  </defs>
  <rect id="eQVNhIKm4qz3" width="700" height="520" fill="url(#eQVNhIKm4qz3-fill)" stroke-width="0"/>
</svg>
''';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnimatedSvgPicture.string(
                svgString,
                width: 700,
                height: 400,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(AnimatedSvgPicture), findsOneWidget);
      },
    );
  });
}
