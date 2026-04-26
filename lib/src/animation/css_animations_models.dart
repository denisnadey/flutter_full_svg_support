part of 'css_animations.dart';

/// Result of decomposing a CSS 3D transform for SMIL conversion.
/// Holds the SMIL transform type and its numeric values.
@immutable
class Css3DDecompositionResult {
  const Css3DDecompositionResult({
    required this.smilType,
    required this.values,
    this.zTranslation,
    this.zScale,
    this.perspectiveDistance,
    this.is3D = false,
  });

  /// The SMIL transform type (translate, rotate, scale, skewX, skewY, matrix).
  final String smilType;

  /// The numeric values for the transform.
  final List<double> values;

  /// Z-axis translation (preserved from translate3d/translateZ).
  final double? zTranslation;

  /// Z-axis scale (preserved from scale3d/scaleZ).
  final double? zScale;

  /// Perspective distance if this came from a perspective() transform.
  final double? perspectiveDistance;

  /// Whether this originated from a 3D transform.
  final bool is3D;

  /// Converts this decomposition result to a SMIL transform string.
  String toSmilString() {
    if (values.isEmpty) return '';
    final formattedValues = values
        .map((v) {
          // Format: remove trailing zeros and unnecessary decimal points
          if (v == v.truncateToDouble()) {
            return v.toStringAsFixed(0);
          }
          return v.toString();
        })
        .join(', ');
    return '$smilType($formattedValues)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Css3DDecompositionResult &&
          smilType == other.smilType &&
          _listEquals(values, other.values) &&
          zTranslation == other.zTranslation &&
          zScale == other.zScale &&
          perspectiveDistance == other.perspectiveDistance &&
          is3D == other.is3D;

  @override
  int get hashCode => Object.hash(
    smilType,
    Object.hashAll(values),
    zTranslation,
    zScale,
    perspectiveDistance,
    is3D,
  );

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Utility class for decomposing CSS 3D transforms into SMIL-compatible 2D transforms.
class Css3DTransformDecomposer {
  /// Decompose translate3d(x, y, z) into a 2D translate.
  static Css3DDecompositionResult decomposeTranslate3d(
    double x,
    double y,
    double z,
  ) {
    return Css3DDecompositionResult(
      smilType: 'translate',
      values: [x, y],
      zTranslation: z,
      is3D: true,
    );
  }

  /// Decompose rotateX(angle) into scale/matrix (Y-axis compression).
  static Css3DDecompositionResult decomposeRotateX(double angleDeg) {
    final angleRad = angleDeg * math.pi / 180;
    final cosA = math.cos(angleRad);

    // For small angles, use scale; for larger angles use matrix
    if (angleDeg.abs() <= 45) {
      return Css3DDecompositionResult(
        smilType: 'scale',
        values: [1.0, cosA],
        is3D: true,
      );
    }
    // Matrix form: [1, 0, 0, cos(a), 0, 0]
    return Css3DDecompositionResult(
      smilType: 'matrix',
      values: [1.0, 0.0, 0.0, cosA, 0.0, 0.0],
      is3D: true,
    );
  }

  /// Decompose rotateY(angle) into scale/matrix (X-axis compression).
  static Css3DDecompositionResult decomposeRotateY(double angleDeg) {
    final angleRad = angleDeg * math.pi / 180;
    final cosA = math.cos(angleRad);

    // For small angles, use scale; for larger angles use matrix
    if (angleDeg.abs() <= 45) {
      return Css3DDecompositionResult(
        smilType: 'scale',
        values: [cosA, 1.0],
        is3D: true,
      );
    }
    // Matrix form: [cos(a), 0, 0, 1, 0, 0]
    return Css3DDecompositionResult(
      smilType: 'matrix',
      values: [cosA, 0.0, 0.0, 1.0, 0.0, 0.0],
      is3D: true,
    );
  }

  /// Decompose rotateZ(angle) into a 2D rotate (no 3D effect).
  static Css3DDecompositionResult decomposeRotateZ(double angleDeg) {
    return Css3DDecompositionResult(
      smilType: 'rotate',
      values: [angleDeg],
      is3D: false,
    );
  }

  /// Decompose rotate3d(x, y, z, angle) into appropriate 2D transform.
  static Css3DDecompositionResult decomposeRotate3d(
    double x,
    double y,
    double z,
    double angleDeg,
  ) {
    // Normalize the axis vector
    final length = math.sqrt(x * x + y * y + z * z);
    if (length < 0.0001) {
      // Zero-length axis = no rotation
      return const Css3DDecompositionResult(
        smilType: 'rotate',
        values: [0.0],
        is3D: false,
      );
    }

    final nx = x / length;
    final ny = y / length;
    final nz = z / length;

    // If Z-dominant, use simple rotation
    if (nz.abs() > 0.99) {
      return Css3DDecompositionResult(
        smilType: 'rotate',
        values: [angleDeg * (nz > 0 ? 1.0 : -1.0)],
        is3D: false,
      );
    }

    // Otherwise compute matrix
    final angleRad = angleDeg * math.pi / 180;
    final c = math.cos(angleRad);
    final s = math.sin(angleRad);
    final t = 1 - c;

    // 3D rotation matrix elements (extracted for 2D portion)
    final m00 = t * nx * nx + c;
    final m01 = t * nx * ny - s * nz;
    final m10 = t * nx * ny + s * nz;
    final m11 = t * ny * ny + c;

    return Css3DDecompositionResult(
      smilType: 'matrix',
      values: [m00, m10, m01, m11, 0.0, 0.0],
      is3D: true,
    );
  }

  /// Decompose scale3d(x, y, z) into a 2D scale.
  static Css3DDecompositionResult decomposeScale3d(
    double sx,
    double sy,
    double sz,
  ) {
    return Css3DDecompositionResult(
      smilType: 'scale',
      values: [sx, sy],
      zScale: sz,
      is3D: true,
    );
  }

  /// Decompose perspective(d) into identity matrix with perspective metadata.
  static Css3DDecompositionResult decomposePerspective(double distance) {
    return Css3DDecompositionResult(
      smilType: 'matrix',
      values: [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
      perspectiveDistance: distance,
      is3D: true,
    );
  }

  /// Decompose matrix3d (16 values) into a 2D matrix (6 values).
  static Css3DDecompositionResult decomposeMatrix3d(List<double> values) {
    if (values.length < 16) {
      return const Css3DDecompositionResult(
        smilType: 'matrix',
        values: [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
        is3D: true,
      );
    }

    // Extract 2D portion: a=m[0], b=m[1], c=m[4], d=m[5], e=m[12], f=m[13]
    // Matrix3d is column-major: [m00,m10,m20,m30, m01,m11,m21,m31, ...]
    return Css3DDecompositionResult(
      smilType: 'matrix',
      values: [
        values[0], // a (m00)
        values[1], // b (m10)
        values[4], // c (m01)
        values[5], // d (m11)
        values[12], // e (tx)
        values[13], // f (ty)
      ],
      is3D: true,
    );
  }

  /// Combine multiple decomposition results into a single matrix.
  static Css3DDecompositionResult combineResults(
    List<Css3DDecompositionResult> results,
  ) {
    if (results.isEmpty) {
      return const Css3DDecompositionResult(
        smilType: 'matrix',
        values: [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
      );
    }
    if (results.length == 1) {
      return results.first;
    }

    // Start with identity
    var a = 1.0, b = 0.0, c = 0.0, d = 1.0, e = 0.0, f = 0.0;
    double? perspective;
    var has3D = false;

    for (final result in results) {
      if (result.is3D) has3D = true;
      if (result.perspectiveDistance != null) {
        perspective = result.perspectiveDistance;
      }

      final vals = _toMatrix(result);
      // Matrix multiplication: new = old * vals
      final na = a * vals[0] + c * vals[1];
      final nb = b * vals[0] + d * vals[1];
      final nc = a * vals[2] + c * vals[3];
      final nd = b * vals[2] + d * vals[3];
      final ne = a * vals[4] + c * vals[5] + e;
      final nf = b * vals[4] + d * vals[5] + f;
      a = na;
      b = nb;
      c = nc;
      d = nd;
      e = ne;
      f = nf;
    }

    return Css3DDecompositionResult(
      smilType: 'matrix',
      values: [a, b, c, d, e, f],
      perspectiveDistance: perspective,
      is3D: has3D,
    );
  }

  /// Convert any decomposition result to a 6-value matrix.
  static List<double> _toMatrix(Css3DDecompositionResult result) {
    switch (result.smilType) {
      case 'translate':
        return [
          1.0,
          0.0,
          0.0,
          1.0,
          result.values.isNotEmpty ? result.values[0] : 0.0,
          result.values.length > 1 ? result.values[1] : 0.0,
        ];
      case 'scale':
        return [
          result.values.isNotEmpty ? result.values[0] : 1.0,
          0.0,
          0.0,
          result.values.length > 1 ? result.values[1] : 1.0,
          0.0,
          0.0,
        ];
      case 'rotate':
        final rad =
            (result.values.isNotEmpty ? result.values[0] : 0.0) * math.pi / 180;
        final cos = math.cos(rad);
        final sin = math.sin(rad);
        return [cos, sin, -sin, cos, 0.0, 0.0];
      case 'skewX':
        final rad =
            (result.values.isNotEmpty ? result.values[0] : 0.0) * math.pi / 180;
        return [1.0, 0.0, math.tan(rad), 1.0, 0.0, 0.0];
      case 'skewY':
        final rad =
            (result.values.isNotEmpty ? result.values[0] : 0.0) * math.pi / 180;
        return [1.0, math.tan(rad), 0.0, 1.0, 0.0, 0.0];
      case 'matrix':
        if (result.values.length >= 6) {
          return result.values.sublist(0, 6);
        }
        return [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
      default:
        return [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
    }
  }

  /// Parse a transform string and decompose each function.
  /// Returns a list of decomposition results.
  static List<Css3DDecompositionResult> decomposeTransformString(
    String transform,
  ) {
    if (transform.isEmpty) return [];

    final results = <Css3DDecompositionResult>[];
    final funcRegex = RegExp(
      r'(translate3d|translatez|translatex|translatey|translate|rotate3d|rotatex|rotatey|rotatez|rotate|scale3d|scalez|scalex|scaley|scale|skewx|skewy|matrix3d|matrix|perspective)\s*\(',
      caseSensitive: false,
    );

    for (final match in funcRegex.allMatches(transform)) {
      final funcName = match.group(1)!.toLowerCase();
      final argsStart = match.end;

      // Find matching closing paren
      var depth = 1;
      var i = argsStart;
      while (i < transform.length && depth > 0) {
        if (transform[i] == '(') depth++;
        if (transform[i] == ')') depth--;
        i++;
      }
      if (depth != 0) continue;

      final argsString = transform.substring(argsStart, i - 1);
      final args = _parseArgs(argsString);

      final result = _decomposeFunction(funcName, args);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  /// Parse function arguments, handling commas and spaces.
  static List<double> _parseArgs(String argsString) {
    final args = <double>[];
    final buffer = StringBuffer();
    var depth = 0;

    for (var i = 0; i < argsString.length; i++) {
      final char = argsString[i];
      if (char == '(') {
        depth++;
        buffer.write(char);
      } else if (char == ')') {
        depth--;
        buffer.write(char);
      } else if ((char == ',' || char == ' ') && depth == 0) {
        if (buffer.isNotEmpty) {
          final val = _parseNumeric(buffer.toString().trim());
          if (val != null) args.add(val);
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      final val = _parseNumeric(buffer.toString().trim());
      if (val != null) args.add(val);
    }

    return args;
  }

  /// Parse a numeric value (with optional unit) to double.
  static double? _parseNumeric(String value) {
    if (value.isEmpty) return null;

    // Handle units: deg, rad, turn, px, %, etc.
    final match = RegExp(
      r'^([+-]?[\d.]+(?:[eE][+-]?\d+)?)\s*(deg|rad|turn|px|%)?$',
    ).firstMatch(value.toLowerCase());
    if (match == null) return double.tryParse(value);

    final num = double.tryParse(match.group(1) ?? '');
    if (num == null) return null;

    final unit = match.group(2) ?? '';
    switch (unit) {
      case 'rad':
        return num * 180 / math.pi;
      case 'turn':
        return num * 360;
      default:
        return num;
    }
  }

  /// Decompose a single transform function.
  static Css3DDecompositionResult? _decomposeFunction(
    String funcName,
    List<double> args,
  ) {
    switch (funcName) {
      case 'translate':
        return Css3DDecompositionResult(
          smilType: 'translate',
          values: [
            args.isNotEmpty ? args[0] : 0.0,
            args.length > 1 ? args[1] : 0.0,
          ],
          is3D: false,
        );
      case 'translatex':
        return Css3DDecompositionResult(
          smilType: 'translate',
          values: [args.isNotEmpty ? args[0] : 0.0, 0.0],
          is3D: false,
        );
      case 'translatey':
        return Css3DDecompositionResult(
          smilType: 'translate',
          values: [0.0, args.isNotEmpty ? args[0] : 0.0],
          is3D: false,
        );
      case 'translate3d':
        return decomposeTranslate3d(
          args.isNotEmpty ? args[0] : 0.0,
          args.length > 1 ? args[1] : 0.0,
          args.length > 2 ? args[2] : 0.0,
        );
      case 'translatez':
        return decomposeTranslate3d(0.0, 0.0, args.isNotEmpty ? args[0] : 0.0);
      case 'rotate':
        return Css3DDecompositionResult(
          smilType: 'rotate',
          values: [args.isNotEmpty ? args[0] : 0.0],
          is3D: false,
        );
      case 'rotatez':
        return decomposeRotateZ(args.isNotEmpty ? args[0] : 0.0);
      case 'rotatex':
        return decomposeRotateX(args.isNotEmpty ? args[0] : 0.0);
      case 'rotatey':
        return decomposeRotateY(args.isNotEmpty ? args[0] : 0.0);
      case 'rotate3d':
        return decomposeRotate3d(
          args.isNotEmpty ? args[0] : 0.0,
          args.length > 1 ? args[1] : 0.0,
          args.length > 2 ? args[2] : 0.0,
          args.length > 3 ? args[3] : 0.0,
        );
      case 'scale':
        final sx = args.isNotEmpty ? args[0] : 1.0;
        return Css3DDecompositionResult(
          smilType: 'scale',
          values: [sx, args.length > 1 ? args[1] : sx],
          is3D: false,
        );
      case 'scalex':
        return Css3DDecompositionResult(
          smilType: 'scale',
          values: [args.isNotEmpty ? args[0] : 1.0, 1.0],
          is3D: false,
        );
      case 'scaley':
        return Css3DDecompositionResult(
          smilType: 'scale',
          values: [1.0, args.isNotEmpty ? args[0] : 1.0],
          is3D: false,
        );
      case 'scale3d':
        return decomposeScale3d(
          args.isNotEmpty ? args[0] : 1.0,
          args.length > 1 ? args[1] : 1.0,
          args.length > 2 ? args[2] : 1.0,
        );
      case 'scalez':
        return decomposeScale3d(1.0, 1.0, args.isNotEmpty ? args[0] : 1.0);
      case 'skewx':
        return Css3DDecompositionResult(
          smilType: 'skewX',
          values: [args.isNotEmpty ? args[0] : 0.0],
          is3D: false,
        );
      case 'skewy':
        return Css3DDecompositionResult(
          smilType: 'skewY',
          values: [args.isNotEmpty ? args[0] : 0.0],
          is3D: false,
        );
      case 'matrix':
        return Css3DDecompositionResult(
          smilType: 'matrix',
          values: args.length >= 6
              ? args.sublist(0, 6)
              : [1.0, 0.0, 0.0, 1.0, 0.0, 0.0],
          is3D: false,
        );
      case 'matrix3d':
        return decomposeMatrix3d(args);
      case 'perspective':
        return decomposePerspective(args.isNotEmpty ? args[0] : 0.0);
      default:
        return null;
    }
  }
}

/// CSS Keyframe rule
class CssKeyframe {
  final double offset; // 0.0 - 1.0
  final Map<String, String> properties;

  /// Per-keyframe timing function override (animation-timing-function in keyframe body).
  /// Applies to the interval starting at this keyframe. null means use animation-level default.
  final String? timingFunction;

  CssKeyframe({
    required this.offset,
    required this.properties,
    this.timingFunction,
  });
}

/// CSS @keyframes animation
class CssKeyframes {
  final String name;
  final List<CssKeyframe> keyframes;

  CssKeyframes({required this.name, required this.keyframes});
}

/// CSS Animation property (shorthand)
/// animation: name duration timing-function delay iteration-count direction fill-mode play-state;
class CssAnimation {
  final String name;
  final Duration duration;
  final String timingFunction; // ease, linear, ease-in, etc.
  final Duration delay;
  final double iterationCount; // 1.0, 2.0, or double.infinity for 'infinite'
  final String direction; // normal, reverse, alternate, alternate-reverse
  final String fillMode; // none, forwards, backwards, both
  final String playState; // running, paused

  CssAnimation({
    required this.name,
    required this.duration,
    this.timingFunction = 'ease',
    this.delay = Duration.zero,
    this.iterationCount = 1.0,
    this.direction = 'normal',
    this.fillMode = 'none',
    this.playState = 'running',
  });

  /// Returns true if the animation is paused
  bool get isPaused => playState.toLowerCase() == 'paused';
}

/// CSS rule targeting elements via selector (id, class, element, etc.).
/// Example: `#myId { animation: spin 1s; fill: red; }`
class CssSelectorRule {
  /// The raw selector string, e.g. `#myId`, `.myClass`, `circle`
  final String selector;

  /// Parsed CSS selector (lazily computed)
  CssSelector? _parsedSelector;

  /// All CSS declarations in the rule body (property → value).
  final Map<String, String> declarations;

  CssSelectorRule({required this.selector, required this.declarations});

  /// Get the parsed CSS selector
  CssSelector? get parsedSelector {
    _parsedSelector ??= _parseCssSelector(selector);
    return _parsedSelector;
  }

  /// Whether this rule targets an `id` selector.
  bool get isIdSelector => selector.startsWith('#');

  /// Whether this rule targets a `class` selector.
  bool get isClassSelector =>
      selector.startsWith('.') && !selector.contains(' ');

  /// Whether this selector has combinators (space, >, +, ~)
  bool get hasCombinators {
    final parsed = parsedSelector;
    return parsed != null && !parsed.isSimple;
  }

  /// The id value if this is an id selector (without `#`).
  String? get targetId => isIdSelector ? selector.substring(1).trim() : null;

  /// The class name if this is a class selector (without `.`).
  String? get targetClass =>
      isClassSelector ? selector.substring(1).trim() : null;

  /// Whether this rule has any animation-related declarations.
  bool get hasAnimation =>
      declarations.containsKey('animation') ||
      declarations.containsKey('animation-name');

  /// Whether this rule has any transition-related declarations.
  bool get hasTransition =>
      declarations.containsKey('transition') ||
      declarations.containsKey('transition-property');
}

/// CSS Transition property
class CssTransition {
  final String
  property; // property name to transition (e.g., 'opacity', 'transform', 'all')
  final Duration duration;
  final String timingFunction;
  final Duration delay;

  CssTransition({
    required this.property,
    required this.duration,
    this.timingFunction = 'ease',
    this.delay = Duration.zero,
  });
}

/// CSS @media rule
class CssMediaRule {
  final String
  query; // raw media query string (e.g., '(prefers-color-scheme: dark)')
  final List<CssSelectorRule> rules; // CSS rules within this @media block
  final CssMediaCondition? condition; // parsed condition for evaluation

  CssMediaRule({required this.query, required this.rules, this.condition});
}

/// Parsed media query condition for evaluation
class CssMediaCondition {
  final CssMediaFeature feature;
  final String? value;
  final double? numericValue;
  final String? unit;

  CssMediaCondition({
    required this.feature,
    this.value,
    this.numericValue,
    this.unit,
  });

  /// Evaluate this condition against the given context
  bool evaluate(CssMediaContext context) {
    switch (feature) {
      case CssMediaFeature.prefersColorScheme:
        return value?.toLowerCase() == (context.isDarkMode ? 'dark' : 'light');
      case CssMediaFeature.minWidth:
        if (numericValue == null) return false;
        return context.viewportWidth >= _convertToPixels(numericValue!, unit);
      case CssMediaFeature.maxWidth:
        if (numericValue == null) return false;
        return context.viewportWidth <= _convertToPixels(numericValue!, unit);
      case CssMediaFeature.minHeight:
        if (numericValue == null) return false;
        return context.viewportHeight >= _convertToPixels(numericValue!, unit);
      case CssMediaFeature.maxHeight:
        if (numericValue == null) return false;
        return context.viewportHeight <= _convertToPixels(numericValue!, unit);
      case CssMediaFeature.unknown:
        return false;
    }
  }

  double _convertToPixels(double value, String? unit) {
    switch (unit?.toLowerCase()) {
      case 'px':
      case null:
      case '':
        return value;
      case 'em':
      case 'rem':
        return value * 16; // Assume 16px base font size
      case 'vw':
        return value; // Already in viewport units
      case 'vh':
        return value;
      default:
        return value;
    }
  }
}

/// Supported CSS media features
enum CssMediaFeature {
  prefersColorScheme,
  minWidth,
  maxWidth,
  minHeight,
  maxHeight,
  unknown,
}

/// Context for evaluating media queries
class CssMediaContext {
  final double viewportWidth;
  final double viewportHeight;
  final bool isDarkMode;

  CssMediaContext({
    required this.viewportWidth,
    required this.viewportHeight,
    this.isDarkMode = false,
  });
}
