import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_dom.dart';
import 'package:full_svg_flutter/src/animation/svg_length_resolver.dart';

void main() {
  SvgDocument documentWithRoot(SvgNode root) => SvgDocument(root: root);

  test('resolves percentage lengths against the nearest SVG viewport', () {
    final root = SvgNode(
      tagName: 'svg',
      attributes: <String, AnimatableSvgAttribute>{
        'viewBox': AnimatableSvgAttribute(
          name: 'viewBox',
          baseValue: '0 0 200 100',
          type: SvgAttributeType.string,
        ),
      },
    );
    final circle = SvgNode(
      tagName: 'circle',
      attributes: <String, AnimatableSvgAttribute>{
        'cx': AnimatableSvgAttribute(
          name: 'cx',
          baseValue: '50%',
          type: SvgAttributeType.string,
        ),
        'cy': AnimatableSvgAttribute(
          name: 'cy',
          baseValue: '25%',
          type: SvgAttributeType.string,
        ),
        'r': AnimatableSvgAttribute(
          name: 'r',
          baseValue: '50%',
          type: SvgAttributeType.string,
        ),
      },
    );
    root.addChild(circle);
    final document = documentWithRoot(root);

    expect(
      resolveSvgLength(
        circle,
        document,
        'cx',
        reference: SvgLengthReference.horizontal,
      ),
      100,
    );
    expect(
      resolveSvgLength(
        circle,
        document,
        'cy',
        reference: SvgLengthReference.vertical,
      ),
      25,
    );
    expect(
      resolveSvgLength(
        circle,
        document,
        'r',
        reference: SvgLengthReference.normalizedDiagonal,
      ),
      closeTo(math.sqrt(25000) / 2, 0.000001),
    );
  });

  test('uses a nested SVG viewport for percentage lengths', () {
    final root = SvgNode(
      tagName: 'svg',
      attributes: <String, AnimatableSvgAttribute>{
        'viewBox': AnimatableSvgAttribute(
          name: 'viewBox',
          baseValue: '0 0 200 100',
          type: SvgAttributeType.string,
        ),
      },
    );
    final nested = SvgNode(
      tagName: 'svg',
      attributes: <String, AnimatableSvgAttribute>{
        'viewBox': AnimatableSvgAttribute(
          name: 'viewBox',
          baseValue: '0 0 40 80',
          type: SvgAttributeType.string,
        ),
      },
    );
    final rect = SvgNode(
      tagName: 'rect',
      attributes: <String, AnimatableSvgAttribute>{
        'width': AnimatableSvgAttribute(
          name: 'width',
          baseValue: '50%',
          type: SvgAttributeType.string,
        ),
        'height': AnimatableSvgAttribute(
          name: 'height',
          baseValue: '25%',
          type: SvgAttributeType.string,
        ),
      },
    );
    root.addChild(nested);
    nested.addChild(rect);
    final document = documentWithRoot(root);

    expect(
      resolveSvgLength(
        rect,
        document,
        'width',
        reference: SvgLengthReference.horizontal,
      ),
      20,
    );
    expect(
      resolveSvgLength(
        rect,
        document,
        'height',
        reference: SvgLengthReference.vertical,
      ),
      20,
    );
  });

  test('keeps unitless and px lengths numeric', () {
    final root = SvgNode(tagName: 'svg');
    final rect = SvgNode(
      tagName: 'rect',
      attributes: <String, AnimatableSvgAttribute>{
        'x': AnimatableSvgAttribute(
          name: 'x',
          baseValue: '12.5',
          type: SvgAttributeType.string,
        ),
        'y': AnimatableSvgAttribute(
          name: 'y',
          baseValue: '4px',
          type: SvgAttributeType.string,
        ),
      },
    );
    root.addChild(rect);
    final document = documentWithRoot(root);

    expect(
      resolveSvgLength(
        rect,
        document,
        'x',
        reference: SvgLengthReference.horizontal,
      ),
      12.5,
    );
    expect(
      resolveSvgLength(
        rect,
        document,
        'y',
        reference: SvgLengthReference.vertical,
      ),
      4,
    );
  });
}
