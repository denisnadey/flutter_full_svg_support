import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';

void main() {
  group('SVG Filters Parsing', () {
    test('Parse feGaussianBlur filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blur">
      <feGaussianBlur stdDeviation="5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blur)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('blur'), isTrue);

      final filter = document.filters!.getById('blur');
      expect(filter, isNotNull);
      expect(filter!.type.toString(), contains('gaussianBlur'));
    });

    test('Parse feDropShadow filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="shadow">
      <feDropShadow dx="2" dy="2" stdDeviation="3" flood-color="black"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#shadow)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('shadow'), isTrue);

      final filter = document.filters!.getById('shadow');
      expect(filter, isNotNull);
      expect(filter!.type.toString(), contains('dropShadow'));
    });

    test('Parse feColorMatrix filter with saturate', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="grayscale">
      <feColorMatrix type="saturate" values="0"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#grayscale)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('grayscale'), isTrue);

      final filter = document.filters!.getById('grayscale');
      expect(filter, isNotNull);
      expect(filter!.type.toString(), contains('colorMatrix'));
    });

    test('Filter applied via filter attribute', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blur">
      <feGaussianBlur stdDeviation="5"/>
    </filter>
  </defs>
  <rect id="rect1" x="10" y="10" width="50" height="50" fill="blue" filter="url(#blur)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final rect = document.getElementById('rect1');
      expect(rect, isNotNull);

      final filterAttr = rect!.getAttributeValue('filter');
      expect(filterAttr, isNotNull);
      expect(filterAttr.toString(), contains('blur'));
    });
  });
}
