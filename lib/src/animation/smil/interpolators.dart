import 'dart:ui' as ui;

import '../css_named_colors.dart';
import '../path_data.dart';
import '../path_normalizer.dart';
import '../path_parser.dart';
import '../svg_dom.dart';
import '../svg_transform.dart';

part 'interpolators_color_parsing.dart';
part 'interpolators_path.dart';
part 'interpolators_transform.dart';

/// Utilities for interpolating various value types.
class Interpolators {
  Interpolators._();

  /// Interpolate a value based on its type.
  static Object? interpolate(
    Object from,
    Object to,
    double t,
    SvgAttributeType type,
  ) {
    switch (type) {
      case SvgAttributeType.number:
      case SvgAttributeType.length:
        return interpolateNumber(from, to, t);
      case SvgAttributeType.color:
        return interpolateColor(from, to, t);
      case SvgAttributeType.transform:
        return interpolateTransform(from, to, t);
      case SvgAttributeType.path:
        return interpolatePath(from, to, t);
      case SvgAttributeType.points:
      case SvgAttributeType.list:
        return interpolateList(from, to, t);
      case SvgAttributeType.string:
      case SvgAttributeType.url:
        return t < 0.5 ? from : to;
    }
  }

  /// Interpolate a numeric value.
  static double interpolateNumber(Object from, Object to, double t) {
    final fromNum = _toNumber(from);
    final toNum = _toNumber(to);

    if (fromNum == null || toNum == null) {
      return toNum ?? fromNum ?? 0.0;
    }
    return fromNum + (toNum - fromNum) * t;
  }

  /// Interpolate a color.
  static ui.Color interpolateColor(Object from, Object to, double t) {
    final fromColor = _toColor(from);
    final toColor = _toColor(to);

    if (fromColor == null || toColor == null) {
      return toColor ?? fromColor ?? const ui.Color(0xFF000000);
    }

    final r = _lerpInt(
      _colorChannelToInt(fromColor.r),
      _colorChannelToInt(toColor.r),
      t,
    );
    final g = _lerpInt(
      _colorChannelToInt(fromColor.g),
      _colorChannelToInt(toColor.g),
      t,
    );
    final b = _lerpInt(
      _colorChannelToInt(fromColor.b),
      _colorChannelToInt(toColor.b),
      t,
    );
    final a = _lerpInt(
      _colorChannelToInt(fromColor.a),
      _colorChannelToInt(toColor.a),
      t,
    );

    return ui.Color.fromARGB(a, r, g, b);
  }

  /// Interpolate an SVG path.
  static String interpolatePath(Object from, Object to, double t) {
    return _interpolatePathValue(from, to, t);
  }

  /// Interpolate a list of values (e.g., for points, stroke-dasharray).
  static List<double> interpolateList(Object from, Object to, double t) {
    final fromList = _toNumberList(from);
    final toList = _toNumberList(to);

    if (fromList == null || toList == null) {
      return toList ?? fromList ?? <double>[];
    }

    if (fromList.length != toList.length) {
      return t < 0.5 ? fromList : toList;
    }

    final result = <double>[];
    for (int i = 0; i < fromList.length; i++) {
      result.add(fromList[i] + (toList[i] - fromList[i]) * t);
    }
    return result;
  }

  /// Interpolate a transform.
  static String interpolateTransform(Object from, Object to, double t) {
    return _interpolateTransformValue(from, to, t);
  }

  /// Add two values together (for additive='sum').
  static Object? add(Object base, Object delta, SvgAttributeType type) {
    switch (type) {
      case SvgAttributeType.number:
      case SvgAttributeType.length:
        final baseNum = _toNumber(base);
        final deltaNum = _toNumber(delta);
        if (baseNum != null && deltaNum != null) {
          return baseNum + deltaNum;
        }
        return base;
      case SvgAttributeType.list:
      case SvgAttributeType.points:
        final baseList = _toNumberList(base);
        final deltaList = _toNumberList(delta);
        if (baseList != null &&
            deltaList != null &&
            baseList.length == deltaList.length) {
          final result = <double>[];
          for (int i = 0; i < baseList.length; i++) {
            result.add(baseList[i] + deltaList[i]);
          }
          return result;
        }
        return base;
      case SvgAttributeType.transform:
        // For transforms, additive="sum" means post-multiply (concatenate).
        // Per SMIL spec: the animated transform is appended to the base transform list.
        final baseStr = base.toString().trim();
        final deltaStr = delta.toString().trim();
        if (baseStr.isEmpty || baseStr.toLowerCase() == 'none') return delta;
        if (deltaStr.isEmpty || deltaStr.toLowerCase() == 'none') return base;
        return '$baseStr $deltaStr';
      default:
        return base;
    }
  }
}
