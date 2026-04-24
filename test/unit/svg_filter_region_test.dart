import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  test('filter region defaults for objectBoundingBox', () {
    const svg = '''
      <svg viewBox="0 0 10 10">
        <defs>
          <filter id="f"/>
        </defs>
      </svg>
    ''';

    final doc = SvgParser.parse(svg);
    final region = doc.filters!.getFilterRegion('f');
    expect(region.x, equals(-0.10));
    expect(region.width, equals(1.20));
    expect(region.isObjectBoundingBox, isTrue);
  });

  test('filter region for userSpaceOnUse with omitted values', () {
    const svg = '''
      <svg viewBox="0 0 10 10">
        <defs>
          <filter id="f" filterUnits="userSpaceOnUse"/>
        </defs>
      </svg>
    ''';

    final doc = SvgParser.parse(svg);
    final region = doc.filters!.getFilterRegion('f');
    expect(region.width, equals(0.0));
    expect(region.isObjectBoundingBox, isFalse);
  });
}
