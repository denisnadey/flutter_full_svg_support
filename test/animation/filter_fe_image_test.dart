import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_svg/src/animation/svg_parser.dart';
import 'package:flutter_svg/src/animation/svg_filters.dart';

void main() {
  // ===========================================================================
  // feImage Filter Primitive Tests
  // ===========================================================================
  group('feImage filter primitive', () {
    // =========================================================================
    // Element reference tests (#id)
    // =========================================================================
    group('Element reference rendering', () {
      test('feImage with element reference creates SvgFeImagePaintPass', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <rect id="myRect" x="0" y="0" width="50" height="50" fill="red"/>
    <filter id="imgFx">
      <feImage href="#myRect" x="0" y="0" width="100" height="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('imgFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgFeImagePaintPass>());

        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.isElementReference, isTrue);
        expect(feImagePass.referencedElementId, 'myRect');
        expect(feImagePass.isExternalImage, isFalse);
      });

      test('feImage with xlink:href element reference', () {
        final svgString = '''
<svg viewBox="0 0 100 100" xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <circle id="myCircle" cx="25" cy="25" r="20" fill="green"/>
    <filter id="xlinkImgFx">
      <feImage xlink:href="#myCircle" x="0" y="0" width="50" height="50"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#xlinkImgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('xlinkImgFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgFeImagePaintPass>());

        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.isElementReference, isTrue);
        expect(feImagePass.referencedElementId, 'myCircle');
      });

      test('feImage element reference with complex nested element', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <g id="myGroup">
      <rect x="0" y="0" width="20" height="20" fill="red"/>
      <circle cx="30" cy="10" r="10" fill="blue"/>
    </g>
    <filter id="groupImgFx">
      <feImage href="#myGroup" x="0" y="0" width="100" height="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#groupImgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('groupImgFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgFeImagePaintPass>());

        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.referencedElementId, 'myGroup');
      });
    });

    // =========================================================================
    // preserveAspectRatio tests
    // =========================================================================
    group('preserveAspectRatio handling', () {
      test('feImage with preserveAspectRatio="none"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="parNoneFx">
      <feImage href="#myRect" x="0" y="0" width="100" height="50" 
               preserveAspectRatio="none"/>
    </filter>
    <rect id="myRect" width="50" height="50" fill="red"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#parNoneFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('parNoneFx');

        expect(passes, hasLength(1));
        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.feImageFilter.preserveAspectRatio, 'none');
      });

      test('feImage with preserveAspectRatio="xMidYMid meet"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="parMeetFx">
      <feImage href="#myRect" x="0" y="0" width="100" height="100" 
               preserveAspectRatio="xMidYMid meet"/>
    </filter>
    <rect id="myRect" width="50" height="50" fill="red"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#parMeetFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('parMeetFx');

        expect(passes, hasLength(1));
        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.feImageFilter.preserveAspectRatio, 'xMidYMid meet');
      });

      test('feImage with preserveAspectRatio="xMinYMin slice"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="parSliceFx">
      <feImage href="#myRect" x="0" y="0" width="100" height="100" 
               preserveAspectRatio="xMinYMin slice"/>
    </filter>
    <rect id="myRect" width="50" height="50" fill="red"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#parSliceFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('parSliceFx');

        expect(passes, hasLength(1));
        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.feImageFilter.preserveAspectRatio, 'xMinYMin slice');
      });

      test('feImage with preserveAspectRatio="xMaxYMax meet"', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="parMaxFx">
      <feImage href="#myRect" x="0" y="0" width="100" height="100" 
               preserveAspectRatio="xMaxYMax meet"/>
    </filter>
    <rect id="myRect" width="50" height="50" fill="red"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#parMaxFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('parMaxFx');

        expect(passes, hasLength(1));
        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.feImageFilter.preserveAspectRatio, 'xMaxYMax meet');
      });
    });

    // =========================================================================
    // External image tests
    // =========================================================================
    group('External image handling', () {
      test('feImage with data URI creates SvgFeImagePaintPass', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="dataUriFx">
      <feImage href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==" 
               x="0" y="0" width="100" height="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#dataUriFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('dataUriFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgFeImagePaintPass>());

        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.isExternalImage, isTrue);
        expect(feImagePass.isElementReference, isFalse);
        expect(feImagePass.feImageFilter.href, startsWith('data:image/png'));
      });

      test('feImage with HTTP URL creates SvgFeImagePaintPass', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="httpImgFx">
      <feImage href="https://example.com/image.png" 
               x="0" y="0" width="100" height="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#httpImgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('httpImgFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgFeImagePaintPass>());

        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.isExternalImage, isTrue);
        expect(feImagePass.feImageFilter.href, 'https://example.com/image.png');
      });

      test('feImage with relative path creates SvgFeImagePaintPass', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="relativeImgFx">
      <feImage href="images/photo.jpg" 
               x="0" y="0" width="100" height="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#relativeImgFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('relativeImgFx');

        expect(passes, hasLength(1));
        expect(passes.single, isA<SvgFeImagePaintPass>());

        final feImagePass = passes.single as SvgFeImagePaintPass;
        expect(feImagePass.isExternalImage, isTrue);
        expect(feImagePass.feImageFilter.href, 'images/photo.jpg');
      });
    });

    // =========================================================================
    // Unresolvable reference tests
    // =========================================================================
    group('Unresolvable reference handling', () {
      test('feImage with empty href returns SourceGraphic fallback', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="emptyHrefFx">
      <feImage href="" x="0" y="0" width="100" height="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#emptyHrefFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('emptyHrefFx');

        // Empty href should fall back to SourceGraphic
        expect(passes, hasLength(1));
        expect(passes.single, isNot(isA<SvgFeImagePaintPass>()));
      });

      test('feImage without href returns previous or SourceGraphic', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="noHrefFx">
      <feImage x="0" y="0" width="100" height="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#noHrefFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('noHrefFx');

        // No href should fall back to SourceGraphic
        expect(passes, hasLength(1));
        expect(passes.single, isNot(isA<SvgFeImagePaintPass>()));
      });

      test('feImage with whitespace-only href returns fallback', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="whitespaceHrefFx">
      <feImage href="   " x="0" y="0" width="100" height="100"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#whitespaceHrefFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('whitespaceHrefFx');

        // Whitespace href should fall back to SourceGraphic
        expect(passes, hasLength(1));
        expect(passes.single, isNot(isA<SvgFeImagePaintPass>()));
      });
    });

    // =========================================================================
    // Subregion tests
    // =========================================================================
    group('Primitive subregion', () {
      test('feImage subregion is correctly parsed', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="subregionFx">
      <feImage href="#myRect" x="10" y="20" width="30" height="40"/>
    </filter>
    <rect id="myRect" width="50" height="50" fill="red"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#subregionFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('subregionFx');

        expect(passes, hasLength(1));
        final feImagePass = passes.single as SvgFeImagePaintPass;
        final subregion = feImagePass.subregion;

        expect(subregion.left, 10.0);
        expect(subregion.top, 20.0);
        expect(subregion.width, 30.0);
        expect(subregion.height, 40.0);
      });

      test('feImage default subregion is zero', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="defaultSubregionFx">
      <feImage href="#myRect"/>
    </filter>
    <rect id="myRect" width="50" height="50" fill="red"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#defaultSubregionFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('defaultSubregionFx');

        expect(passes, hasLength(1));
        final feImagePass = passes.single as SvgFeImagePaintPass;
        final subregion = feImagePass.subregion;

        expect(subregion.left, 0.0);
        expect(subregion.top, 0.0);
        expect(subregion.width, 0.0);
        expect(subregion.height, 0.0);
      });
    });

    // =========================================================================
    // Filter chain integration tests
    // =========================================================================
    group('Filter chain integration', () {
      test('feImage followed by feGaussianBlur', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <rect id="myRect" width="50" height="50" fill="red"/>
    <filter id="imgBlurFx">
      <feImage href="#myRect" x="0" y="0" width="100" height="100" result="img"/>
      <feGaussianBlur in="img" stdDeviation="3"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgBlurFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('imgBlurFx');

        expect(passes, hasLength(1));
        // The blur should be applied to the feImage pass
        expect(passes.single.imageFilter, isNotNull);
      });

      test('feImage in feMerge composition', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <rect id="myRect" width="50" height="50" fill="red"/>
    <filter id="imgMergeFx">
      <feImage href="#myRect" x="0" y="0" width="100" height="100" result="img"/>
      <feMerge>
        <feMergeNode in="img"/>
        <feMergeNode in="SourceGraphic"/>
      </feMerge>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgMergeFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('imgMergeFx');

        // Merge of feImage pass + SourceGraphic
        expect(passes, hasLength(2));
      });

      test('feImage with explicit in attribute uses input instead of href', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <filter id="imgWithInFx">
      <feOffset dx="5" dy="5" result="shifted"/>
      <feImage in="shifted" href="#myRect" x="0" y="0" width="100" height="100"/>
    </filter>
    <rect id="myRect" width="50" height="50" fill="red"/>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgWithInFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('imgWithInFx');

        // When 'in' is specified, feImage uses it instead of rendering href
        expect(passes, hasLength(1));
        expect(passes.single.offset, const ui.Offset(5, 5));
        // Should NOT be SvgFeImagePaintPass since 'in' overrides href
        expect(passes.single, isNot(isA<SvgFeImagePaintPass>()));
      });
    });

    // =========================================================================
    // Result attribute tests
    // =========================================================================
    group('Result attribute handling', () {
      test('feImage result can be referenced by downstream primitives', () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <rect id="myRect" width="50" height="50" fill="red"/>
    <filter id="imgResultFx">
      <feImage href="#myRect" x="0" y="0" width="100" height="100" result="imgResult"/>
      <feOffset dx="10" dy="10"/>
      <feBlend in="imgResult" in2="SourceGraphic" mode="multiply"/>
    </filter>
  </defs>
  <rect x="10" y="10" width="50" height="50" fill="blue" filter="url(#imgResultFx)"/>
</svg>
''';

        final document = SvgParser.parse(svgString);
        final passes = document.filters!.resolvePaintPasses('imgResultFx');

        // Blend combines imgResult and SourceGraphic
        expect(passes, hasLength(2));
      });
    });
  });
}
