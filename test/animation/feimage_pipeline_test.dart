import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  test('feImage primitive resolves to specialized paint pass', () {
    final svg = File(
      'W3C_SVG_11_TestSuite/svg/filters-image-01-b.svg',
    ).readAsStringSync();
    final document = SvgParser.parse(svg);
    final filters = document.filters;
    expect(filters, isNotNull);

    final primitives = filters!.getAllById('image');
    expect(primitives, isNotEmpty);
    expect(
      primitives.any((p) => p.runtimeType.toString() == 'SvgFeImageFilter'),
      isTrue,
    );

    final feImage =
        primitives.firstWhere(
              (p) => p.runtimeType.toString() == 'SvgFeImageFilter',
            )
            as dynamic;
    expect(feImage.href, isNotNull);
    expect(feImage.href.toString(), contains('../images/image1.jpg'));
  });
}
