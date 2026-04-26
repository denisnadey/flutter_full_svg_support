part of 'svg_parser.dart';

const Set<String> _numericAttributes = {
  'x',
  'y',
  'cx',
  'cy',
  'r',
  'rx',
  'ry',
  'width',
  'height',
  'x1',
  'y1',
  'x2',
  'y2',
  'opacity',
  'fill-opacity',
  'stroke-opacity',
  'stroke-width',
  'stroke-miterlimit',
  'stroke-dashoffset',
  'font-size',
  'letter-spacing',
  'word-spacing',
  'textLength',
  'offset',
};

const Set<String> _colorAttributes = {
  'fill',
  'stroke',
  'stop-color',
  'flood-color',
  'lighting-color',
};

const Set<String> _urlAttributes = {
  'href',
  'xlink:href',
  'clip-path',
  'mask',
  'filter',
};

const Map<String, ui.Color> _namedColors = cssNamedColors;
