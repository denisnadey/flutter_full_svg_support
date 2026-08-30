import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';
import 'package:full_svg_flutter/src/animation/svg_length_resolver.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  group('SMIL mixed percentage interpolation', () {
    test('preserves a percentage endpoint until viewport resolution', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <rect id="target" x="0" width="20" height="20">
            <animate attributeName="x" from="0" to="100%" dur="2s"/>
          </rect>
        </svg>
      ''');
      final target = document.root.findById('target')!;
      final animation = SmilParser.parseAnimations(document).single;

      final value = animation.computeValue(0.5);
      expect(value, isA<SvgLengthPercentageValue>());

      final resolved = resolveSvgLengthValue(
        target,
        value,
        reference: SvgLengthReference.horizontal,
      );
      expect(resolved, 100);
    });

    test('interpolates mixed absolute/percentage values', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <rect id="target" x="0" width="20" height="20">
            <animate attributeName="x" values="0;100%;200" dur="2s"/>
          </rect>
        </svg>
      ''');
      final target = document.root.findById('target')!;
      final animation = SmilParser.parseAnimations(document).single;

      final value = animation.computeValue(0.25);
      expect(value, isA<SvgLengthPercentageValue>());
      // Global progress 0.25 lands in segment 0 (0 -> 100%) at local 0.5,
      // i.e. 50% of the 200-wide viewBox.
      expect(
        resolveSvgLengthValue(
          target,
          value,
          reference: SvgLengthReference.horizontal,
        ),
        100,
      );
    });

    test('preserves signed percentage components in a by animation', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <rect id="target" x="0" width="20" height="20">
            <animate attributeName="x" from="10%" by="-5%" dur="2s"/>
          </rect>
        </svg>
      ''');
      final target = document.root.findById('target')!;
      final animation = SmilParser.parseAnimations(document).single;

      expect(
        resolveSvgLengthValue(
          target,
          animation.computeValue(0.5),
          reference: SvgLengthReference.horizontal,
        ),
        15,
      );
    });

    test('additive="sum" seeds from the raw percentage base', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <rect id="target" x="10%" width="20" height="20">
            <animate attributeName="x" from="0" to="10" dur="2s"
                     additive="sum"/>
          </rect>
        </svg>
      ''');
      final target = document.root.findById('target')!;
      final animation = SmilParser.parseAnimations(document).single;

      // Base 10% of 200 plus the absolute midpoint delta of 5 => 20 + 5 = 25.
      final value = animation.computeValue(0.5);
      expect(value, isA<SvgLengthPercentageValue>());
      expect(
        resolveSvgLengthValue(
          target,
          value,
          reference: SvgLengthReference.horizontal,
        ),
        25,
      );
    });

    test(
      'definition coordinates keep objectBoundingBox percentage semantics',
      () {
        final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs>
            <linearGradient id="gradient">
              <stop offset="0" stop-color="red"/>
              <stop offset="1" stop-color="blue"/>
            </linearGradient>
          </defs>
          <rect width="200" height="100" fill="url(#gradient)"/>
        </svg>
      ''');
        final gradient = document.root.findById('gradient')!;

        expect(
          smilPercentageSemanticsForAttribute('x1', targetNode: gradient),
          SmilPercentageSemantics.objectBoundingBox,
        );
        expect(
          smilPercentageSemanticsForAttribute('x1'),
          SmilPercentageSemantics.horizontalLength,
        );
      },
    );

    test('text coordinates defer percentages for the text consumer', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <text id="target" x="0">A
            <animate attributeName="x" from="0%" to="100%" dur="2s"/>
          </text>
        </svg>
      ''');
      final target = document.root.findById('target')!;
      final animation = SmilParser.parseAnimations(document).single;

      expect(
        animation.percentageSemantics,
        SmilPercentageSemantics.horizontalLength,
      );
      final value = animation.computeValue(0.5);
      expect(value, isA<SvgLengthPercentageValue>());
      expect(
        resolveSvgLengthValue(
          target,
          value,
          reference: SvgLengthReference.horizontal,
        ),
        100,
      );
    });

    test('constructor infers objectBoundingBox semantics for gradient x1', () {
      final document = SvgParser.parse('''
        <svg viewBox="0 0 200 100">
          <defs><linearGradient id="gradient"/></defs>
        </svg>
      ''');
      final gradient = document.root.findById('gradient')!;
      final animation = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: gradient,
        document: document,
        attributeName: 'x1',
        attributeType: SvgAttributeType.length,
        values: const <Object>['0%', '100%'],
        keyTimes: const <double>[0, 1],
        dur: const Duration(seconds: 2),
      );

      expect(
        animation.percentageSemantics,
        SmilPercentageSemantics.objectBoundingBox,
      );
      final value = animation.computeValue(0.5);
      expect(value, isA<SvgLengthPercentageValue>());
      expect((value as SvgLengthPercentageValue).percentage, 50);
    });

    test('constructor generates paced key times from inferred semantics', () {
      final document = SvgParser.parse('''
        <svg><rect id="target" opacity="0"/></svg>
      ''');
      final target = document.root.findById('target')!;
      final animation = SmilAnimation(
        type: SmilAnimationType.animate,
        targetNode: target,
        document: document,
        attributeName: 'opacity',
        attributeType: SvgAttributeType.number,
        values: const <Object>[0.0, 10.0, 110.0],
        dur: const Duration(seconds: 2),
        calcMode: SmilCalcMode.paced,
      );

      expect(animation.computeValue(0.5), closeTo(55, 0.0001));
    });

    for (final baseSource in <String>['style="x: 10%"', 'class="positioned"']) {
      test('additive sum uses the CSS base from $baseSource', () {
        final document = SvgParser.parse('''
          <svg viewBox="0 0 200 100">
            <style>.positioned { x: 10%; }</style>
            <rect id="target" $baseSource width="20" height="20">
              <animate attributeName="x" from="0" to="10" dur="2s"
                       additive="sum"/>
            </rect>
          </svg>
        ''');
        final target = document.root.findById('target')!;
        final animation = SmilParser.parseAnimations(document).single;

        final resolved = resolveSvgLengthValue(
          target,
          animation.computeValue(0.5),
          reference: SvgLengthReference.horizontal,
        );
        expect(resolved, 25);
      });
    }
  });
}
