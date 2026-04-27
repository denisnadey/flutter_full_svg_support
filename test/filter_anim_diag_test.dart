// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:full_svg_flutter/src/animation/svg_parser.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_timeline.dart';
import 'package:full_svg_flutter/src/animation/svg_filters.dart';

void main() {
  test('betinia_wol - filter animation diagnostics', () {
    const svgPath = 'test/animation_goldens/svg_fixtures/betinia_wol.svg';
    final svgFile = File(svgPath);
    if (!svgFile.existsSync()) {
      print('SKIP: betinia_wol.svg not found');
      return;
    }
    final svgStr = svgFile.readAsStringSync();

    final doc = SvgParser.parse(svgStr);
    final animations = SmilParser.parseAnimations(doc);
    print('betinia_wol total animations: ${animations.length}');

    // Check CSS selector rules - make sure filter:none is NOT in them
    final selectorRules = doc.cssSelectorRules ?? [];
    print('\nSelector rules count: ${selectorRules.length}');
    final filterRules = selectorRules
        .where(
          (r) =>
              r.declarations.containsKey('filter') ||
              r.declarations.containsKey('filter'),
        )
        .toList();
    print('Selector rules with "filter" property: ${filterRules.length}');
    for (final r in filterRules) {
      print('  ${r.selector}: filter=${r.declarations['filter']}');
    }

    // Find #_43_to node
    final node43 = doc.root.findById('_43_to');
    print('\n#_43_to node found: ${node43 != null}');
    if (node43 != null) {
      print('#_43_to filter attr: ${node43.getAttributeValue('filter')}');
      print('#_43_to class: ${node43.className}');
    }

    // Check filter animations are found
    final filterAnims = animations
        .where(
          (a) =>
              a.targetNode.tagName == 'feColorMatrix' ||
              a.targetNode.tagName == 'feFuncR' ||
              a.targetNode.tagName == 'feFuncG' ||
              a.targetNode.tagName == 'feFuncB',
        )
        .toList();
    print('\nFilter animations: ${filterAnims.length}');
    expect(
      filterAnims.length,
      8,
      reason: 'Expected 8 filter primitive animations',
    );

    // Seek to t=6429ms
    final timeline = SvgTimeline(animations: animations, rootNode: doc.root);
    timeline.seek(const Duration(milliseconds: 6429));

    // Check #fs1 feColorMatrix after seek
    final fs1Primitives = doc.filters!.getAllById('fs1');
    print('\nfs1 primitives count: ${fs1Primitives.length}');
    for (final p in fs1Primitives) {
      if (p is SvgColorMatrixFilter) {
        final src = p.sourceElement as dynamic;
        final attr = src?.getAttribute('values');
        print(
          'feColorMatrix: isAnimated=${attr?.isAnimated} effective=${attr?.effectiveValue}',
        );

        // Manually simulate _syncColorMatrixValues
        if (attr?.isAnimated == true) {
          final effectiveVal = attr!.effectiveValue;
          print('  Would sync colorMatrix.values to: $effectiveVal');
          expect(p.sourceElement, isNotNull);
        }
      }
      if (p is SvgComponentTransferFilter) {
        final src = p.sourceElement as dynamic;
        print('feComponentTransfer sourceElement: ${src?.tagName}');
        if (src != null) {
          for (final child in (src.children as List)) {
            final slopeAttr = (child as dynamic).getAttribute('slope');
            if (slopeAttr != null) {
              print(
                '  ${child.tagName}.slope: isAnimated=${slopeAttr.isAnimated} effective=${slopeAttr.effectiveValue}',
              );
            }
          }
        }
      }
    }
  });
}
