import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';

void main() {
  group('SVG <symbol> and <use> Animations', () {
    test('animates x, y, width, height on <use> tag referencing <symbol>', () {
      final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <symbol id="mySymbol" viewBox="0 0 50 50">
      <rect width="50" height="50" fill="red" />
    </symbol>
  </defs>
  <use id="u1" href="#mySymbol" x="0" y="0" width="10" height="10">
    <animate attributeName="x" values="0;100" dur="1s" fill="freeze" />
    <animate attributeName="width" values="10;50" dur="1s" fill="freeze" />
  </use>
</svg>
''';

      final document = SvgParser.parse(svgString);
      final animations = SmilParser.parseAnimations(document);

      final useNode = document.root.findById('u1')!;
      expect(useNode.tagName, 'use');

      final xAnim = animations.firstWhere((a) => a.attributeName == 'x');
      final widthAnim = animations.firstWhere(
        (a) => a.attributeName == 'width',
      );

      expect(xAnim.targetNode.id, 'u1');
      expect(widthAnim.targetNode.id, 'u1');

      xAnim.updateForTime(const Duration(milliseconds: 500));
      widthAnim.updateForTime(const Duration(milliseconds: 500));

      expect(useNode.getAttributeValue('x'), 50.0);
      expect(useNode.getAttributeValue('width'), 30.0);
    });
    test(
      'animates inner elements within <symbol> correctly when instantiated',
      () {
        final svgString = '''
<svg viewBox="0 0 100 100">
  <defs>
    <symbol id="mySymbol" viewBox="0 0 50 50">
      <rect id="innerRect" width="50" height="50" fill="red">
        <animate attributeName="opacity" values="1;0" dur="2s" fill="freeze" />
      </rect>
    </symbol>
  </defs>
  <use id="u1" href="#mySymbol" x="0" y="0" width="10" height="10" />
</svg>
''';

        final document = SvgParser.parse(svgString);
        final animations = SmilParser.parseAnimations(document);

        final rectNode = document.root.findById('innerRect')!;

        final opacityAnim = animations.firstWhere(
          (a) => a.attributeName == 'opacity',
        );
        expect(opacityAnim.targetNode.id, 'innerRect');

        opacityAnim.updateForTime(const Duration(seconds: 1));
        expect(rectNode.getAttributeValue('opacity'), 0.5);
      },
    );
  });
}
