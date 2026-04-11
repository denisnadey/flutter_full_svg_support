import 'package:flutter_svg/src/animation/svg_parser_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filter region defaults for objectBoundingBox', () {
    final region = _parseFilterRegion(XmlElement(XmlName('filter')));
    expect(region.x, equals(-0.10));
    expect(region.width, equals(1.20));
  });

  test('filter region for userSpaceOnUse with omitted values', () {
    final region = _parseFilterRegion(XmlElement(XmlName('filter'),
        attributes: [XmlAttribute(XmlName('filterUnits'), 'userSpaceOnUse')]));
    expect(region.width, equals(0.0));
  });
}
