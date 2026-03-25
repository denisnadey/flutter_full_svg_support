import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/css_animations.dart';
import 'package:flutter_svg/src/animation/svg_dom.dart';
import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/smil/smil_animation.dart';
import 'package:flutter_svg/src/animation/smil/smil_parser.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // stroke-dashoffset / stroke-dasharray
  // ─────────────────────────────────────────────────────────────────────────
  group('stroke-dashoffset CSS animation', () {
    test('stroke-dashoffset is parsed as number type in svg_parser', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <path d="M0,0 H100" stroke="red" stroke-dasharray="10 5" stroke-dashoffset="0"/>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final pathNode = document.root.children.firstWhere(
        (n) => n.tagName == 'path',
      );
      final dashOffsetAttr = pathNode.getAttribute('stroke-dashoffset');
      expect(dashOffsetAttr, isNotNull);
      expect(dashOffsetAttr!.type, equals(SvgAttributeType.number));
    });

    test('stroke-dashoffset CSS keyframe animation converts to SMIL', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes draw {
      0%  { stroke-dashoffset: 100; }
      100% { stroke-dashoffset: 0; }
    }
  </style>
  <path id="line" d="M0,50 H100" stroke="blue" stroke-dasharray="100"
        stroke-dashoffset="100"
        style="animation: draw 2s linear forwards;"/>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final dashAnim = animations
          .where((a) => a.attributeName == 'stroke-dashoffset')
          .toList();
      expect(
        dashAnim,
        isNotEmpty,
        reason: 'Expected stroke-dashoffset animation',
      );
      expect(dashAnim.first.attributeType, equals(SvgAttributeType.number));
    });

    test('stroke-dashoffset animates correctly at mid-point', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes draw {
      0%  { stroke-dashoffset: 100; }
      100% { stroke-dashoffset: 0; }
    }
  </style>
  <path id="line" d="M0,50 H100" stroke="blue" stroke-dasharray="100"
        stroke-dashoffset="100"
        style="animation: draw 2s linear forwards;"/>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final dashAnim = animations.firstWhere(
        (a) => a.attributeName == 'stroke-dashoffset',
      );

      // At 1s (50%) expect dashoffset ≈ 50.
      dashAnim.updateForTime(const Duration(seconds: 1));
      final value = dashAnim.targetNode.getAttributeValue('stroke-dashoffset');
      expect(value, isA<double>());
      expect(value as double, closeTo(50.0, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // stop-color CSS animation
  // ─────────────────────────────────────────────────────────────────────────
  group('CSS stop-color animation', () {
    test('stop-color is recognized as color attribute type', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <linearGradient id="g1">
      <stop id="s1" offset="0" stop-color="#ff0000"/>
    </linearGradient>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final defs = document.root.children.firstWhere(
        (n) => n.tagName == 'defs',
      );
      final grad = defs.children.firstWhere(
        (n) => n.tagName == 'linearGradient',
      );
      final stop = grad.children.firstWhere((n) => n.tagName == 'stop');

      final stopColorAttr = stop.getAttribute('stop-color');
      expect(stopColorAttr, isNotNull);
      expect(stopColorAttr!.type, equals(SvgAttributeType.color));
    });

    test('stop-color CSS animation converts to SMIL color animation', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes colorShift {
      0%   { stop-color: #ff0000; }
      100% { stop-color: #00ff00; }
    }
  </style>
  <defs>
    <linearGradient id="g1">
      <stop id="s1" offset="0" stop-color="#ff0000"
            style="animation: colorShift 3s linear infinite;"/>
    </linearGradient>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final colorAnims = animations
          .where((a) => a.attributeName == 'stop-color')
          .toList();
      expect(colorAnims, isNotEmpty, reason: 'Expected stop-color animation');
      expect(colorAnims.first.attributeType, equals(SvgAttributeType.color));
    });

    test('stop-color animates between two colors', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes colorShift {
      0%   { stop-color: #ff0000; }
      100% { stop-color: #00ff00; }
    }
  </style>
  <defs>
    <linearGradient id="g1">
      <stop id="s1" offset="0" stop-color="#ff0000"
            style="animation: colorShift 2s linear forwards;"/>
    </linearGradient>
  </defs>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final anim = animations.firstWhere(
        (a) => a.attributeName == 'stop-color',
      );

      // At t=0 should be red.
      anim.updateForTime(Duration.zero);
      final colorAt0 = anim.targetNode.getAttributeValue('stop-color');
      expect(colorAt0, isA<ui.Color>());
      final c0 = colorAt0 as ui.Color;
      expect((c0.r * 255).round(), greaterThan(200)); // red dominant

      // At t=2s should be green.
      anim.updateForTime(const Duration(seconds: 2));
      final colorAt2 = anim.targetNode.getAttributeValue('stop-color');
      expect(colorAt2, isA<ui.Color>());
      final c2 = colorAt2 as ui.Color;
      expect((c2.g * 255).round(), greaterThan(200)); // green dominant
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Per-keyframe animation-timing-function
  // ─────────────────────────────────────────────────────────────────────────
  group('Per-keyframe animation-timing-function', () {
    test('animation-timing-function extracted from keyframe body', () {
      const cssText = '''
@keyframes bounce {
  0%   { transform: translateY(0); animation-timing-function: ease-in; }
  50%  { transform: translateY(-50px); animation-timing-function: ease-out; }
  100% { transform: translateY(0); }
}
''';
      final keyframes = CssParser.parseKeyframes(cssText);
      expect(keyframes, hasLength(1));
      final kfs = keyframes.first.keyframes;
      expect(kfs, hasLength(3));

      // animation-timing-function should be stored in field, not in properties.
      expect(kfs[0].timingFunction, equals('ease-in'));
      expect(
        kfs[0].properties.containsKey('animation-timing-function'),
        isFalse,
      );
      expect(kfs[1].timingFunction, equals('ease-out'));
      expect(kfs[2].timingFunction, isNull); // last kf has no timing
    });

    test('per-keyframe timing used for keySplines in SMIL', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes pulse {
      0%   { opacity: 0; animation-timing-function: cubic-bezier(0.77,0,0.175,1); }
      100% { opacity: 1; }
    }
  </style>
  <circle cx="50" cy="50" r="20" fill="blue"
          style="animation: pulse 1s linear forwards;"/>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);
      final anim = animations.firstWhere((a) => a.attributeName == 'opacity');

      // Should have spline calcMode because the keyframe overrides to cubic-bezier.
      expect(anim.calcMode, equals(SmilCalcMode.spline));
      expect(anim.keySplines, isNotNull);
      expect(anim.keySplines!, hasLength(1));

      // The cubic-bezier(0.77, 0, 0.175, 1) should be the spline.
      final spline = anim.keySplines!.first;
      expect(spline.x1, closeTo(0.77, 0.01));
      expect(spline.y1, closeTo(0.0, 0.01));
      expect(spline.x2, closeTo(0.175, 0.01));
      expect(spline.y2, closeTo(1.0, 0.01));
    });

    test(
      'mixed per-keyframe: some spline, some linear → all become spline',
      () {
        const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes mixed {
      0%   { opacity: 0; animation-timing-function: cubic-bezier(0.5,0,0.5,1); }
      50%  { opacity: 0.5; }
      100% { opacity: 1; }
    }
  </style>
  <circle cx="50" cy="50" r="20"
          style="animation: mixed 2s linear forwards;"/>
</svg>
''';
        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);
        final anim = animations.firstWhere((a) => a.attributeName == 'opacity');

        expect(anim.calcMode, equals(SmilCalcMode.spline));
        // 2 intervals → 2 keySplines
        expect(anim.keySplines, hasLength(2));
        // Second interval (linear) should map to (0,0,1,1).
        expect(anim.keySplines![1].x1, closeTo(0.0, 0.01));
        expect(anim.keySplines![1].y2, closeTo(1.0, 0.01));
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // CSS compound transform handling (no decomposition - CSS uses REPLACE semantics)
  // ─────────────────────────────────────────────────────────────────────────
  group('CSS compound transform (no decomposition)', () {
    test('compound transform produces single SMIL animation with full string', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes compound {
      0%   { transform: translate(50px,50px) scale(1,1); }
      100% { transform: translate(50px,50px) scale(0.5,0.5); }
    }
  </style>
  <g style="animation: compound 1s linear forwards;"/>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final transformAnims = animations
          .where((a) => a.attributeName == 'transform')
          .toList();

      // Should have exactly ONE transform animation (not decomposed)
      expect(
        transformAnims.length,
        equals(1),
        reason: 'Expected single transform animation, not decomposed',
      );

      // Should use additive=replace (CSS semantics)
      expect(
        transformAnims.first.additive,
        equals(SmilAdditiveMode.replace),
        reason: 'CSS transforms should use replace mode',
      );
    });

    test('compound transform: translate+rotate yields single animation', () {
      const svgString = '''
<svg viewBox="0 0 100 100">
  <style>
    @keyframes spin {
      0%   { transform: translate(10px,20px) rotate(0deg); }
      100% { transform: translate(10px,20px) rotate(360deg); }
    }
  </style>
  <g id="target" style="animation: spin 2s linear forwards;"/>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final transformAnims = animations
          .where((a) => a.attributeName == 'transform')
          .toList();

      // Should produce single animation with compound transform
      expect(
        transformAnims.length,
        equals(1),
        reason: 'Expected single transform animation for compound CSS',
      );

      // Transform type is inferred from first function
      expect(
        transformAnims.first.transformType,
        equals('translate'),
        reason: 'Transform type inferred from first function',
      );
    });

    test('SVGator-style _ts id: single animation with compound transform', () {
      // Simulates the SVGator pattern where a <g> with a compound transform is
      // animated by CSS. Now uses single animation with REPLACE semantics.
      const svgString = '''
<svg viewBox="0 0 992 992">
  <style>
    @keyframes eQVN45_ts__ts {
      0%   { transform: translate(496px,415px) scale(1,1);
             animation-timing-function: cubic-bezier(0.42,0,0.58,1); }
      50%  { transform: translate(496px,415px) scale(0.89,0.89);
             animation-timing-function: cubic-bezier(0.42,0,0.58,1); }
      100% { transform: translate(496px,415px) scale(1,1); }
    }
  </style>
  <g id="eQVN45_ts" style="animation: eQVN45_ts__ts 3000ms linear infinite;"/>
</svg>
''';
      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final transformAnims = animations
          .where((a) => a.attributeName == 'transform')
          .toList();

      // Should have exactly one transform animation (not decomposed)
      expect(
        transformAnims.length,
        equals(1),
        reason: 'Expected single transform animation from SVGator-style keyframe',
      );

      final anim = transformAnims.first;
      // Should repeat infinitely.
      expect(anim.repeatCount, equals(double.infinity));
      // Should use spline (cubic-bezier per keyframe).
      expect(anim.calcMode, equals(SmilCalcMode.spline));
      // Should use replace mode (CSS semantics)
      expect(anim.additive, equals(SmilAdditiveMode.replace));
    });
  });
}
