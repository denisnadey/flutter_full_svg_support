import 'package:flutter_test/flutter_test.dart';

import 'package:full_svg_flutter/src/animation/smil/smil_animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
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
      'definition coordinates keep numeric behavior (no deferred wrapper)',
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
          SmilPercentageSemantics.none,
        );
        expect(
          smilPercentageSemanticsForAttribute('x1'),
          SmilPercentageSemantics.horizontalLength,
        );
      },
    );
  });
}
