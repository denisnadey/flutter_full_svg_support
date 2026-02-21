import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

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

    test('Parse feOffset filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="offsetFilter">
      <feOffset dx="4" dy="6"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#offsetFilter)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('offsetFilter'), isTrue);

      final filter = document.filters!.getById('offsetFilter');
      expect(filter, isNotNull);
      expect(filter!.type.toString(), contains('offset'));
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

    test('Parse feFlood filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="floodFx">
      <feFlood flood-color="#00ff00" flood-opacity="0.5"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#floodFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('floodFx'), isTrue);

      final filter = document.filters!.getById('floodFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgFloodFilter>());
      expect(filter!.type, SvgFilterType.flood);
    });

    test('Parse feBlend filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="blendFx">
      <feBlend mode="multiply"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#blendFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('blendFx'), isTrue);

      final filter = document.filters!.getById('blendFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgBlendFilter>());
      expect(filter!.type, SvgFilterType.blend);
      expect((filter as SvgBlendFilter).mode, ui.BlendMode.multiply);
    });

    test('Parse feComposite filter', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="compFx">
      <feComposite operator="xor"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#compFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('compFx'), isTrue);

      final filter = document.filters!.getById('compFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgCompositeFilter>());
      expect(filter!.type, SvgFilterType.composite);
      final composite = filter as SvgCompositeFilter;
      expect(composite.operatorType, 'xor');
      expect(composite.mode, ui.BlendMode.xor);
    });

    test('Parse feMerge filter with feMergeNode inputs', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="mergeFx">
      <feMerge>
        <feMergeNode in="SourceGraphic"/>
        <feMergeNode in="BackgroundImage"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#mergeFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('mergeFx'), isTrue);

      final filter = document.filters!.getById('mergeFx');
      expect(filter, isNotNull);
      expect(filter, isA<SvgMergeFilter>());
      expect(filter!.type, SvgFilterType.merge);
      final merge = filter as SvgMergeFilter;
      expect(merge.nodeCount, 2);
      expect(merge.nodeInputs, <String?>['SourceGraphic', 'BackgroundImage']);
    });

    test('Composes multi-primitive filter chain in declaration order', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="chainFx">
      <feGaussianBlur stdDeviation="1"/>
      <feOffset dx="2" dy="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#chainFx)"/>
</svg>
''';

      final document = SvgParser.parse(svgString);
      expect(document.filters, isNotNull);
      expect(document.filters!.hasFilter('chainFx'), isTrue);

      final items = document.filters!.getAllById('chainFx');
      expect(items, hasLength(2));
      expect(items.first, isA<SvgGaussianBlurFilter>());
      expect(items.last, isA<SvgOffsetFilter>());
      expect(document.filters!.resolveImageFilter('chainFx'), isNotNull);
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
