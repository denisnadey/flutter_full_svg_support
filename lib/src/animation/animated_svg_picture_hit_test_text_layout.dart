part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateHitTestTextLayoutExtension
    on _AnimatedSvgPictureState {
  _TextMeasure _measureText(
    String text,
    SvgNode node, {
    double additionalLetterSpacing = 0.0,
  }) {
    final fontSize = (_getInheritedNumber(node, 'font-size') ?? 16.0).clamp(
      1.0,
      4096.0,
    );
    final fontFamily = _getInheritedString(node, 'font-family');
    final fontWeight = _resolveFontWeight(
      _getInheritedString(node, 'font-weight'),
    );
    final fontStyle = _resolveFontStyle(
      _getInheritedString(node, 'font-style'),
    );
    final letterSpacing =
        ((_getInheritedNumber(node, 'letter-spacing') ?? 0.0) +
                additionalLetterSpacing)
            .clamp(-1024.0, 1024.0);
    final wordSpacing = (_getInheritedNumber(node, 'word-spacing') ?? 0.0)
        .clamp(-1024.0, 1024.0);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    return _TextMeasure(
      width: painter.width,
      height: painter.height,
      alphabeticBaseline: baseline,
      fontSize: fontSize,
    );
  }

  double? _resolveTextLength(SvgNode node) {
    final value = node.getAttributeValue('textLength');
    if (value == null) {
      return null;
    }
    if (value is num) {
      final length = value.toDouble();
      return length > 0 ? length : null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  _TextLengthAdjust _resolveTextLengthAdjust(SvgNode node) {
    final raw = node.getAttributeValue('lengthAdjust')?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return _TextLengthAdjust.spacing;
    }
    return raw.toLowerCase() == 'spacingandglyphs'
        ? _TextLengthAdjust.spacingAndGlyphs
        : _TextLengthAdjust.spacing;
  }

  double _resolveTextTopFromBaseline({
    required SvgNode node,
    required double baselineY,
    required _TextMeasure metrics,
  }) {
    final dominantBaseline = _resolveDominantBaseline(
      _getInheritedString(node, 'dominant-baseline') ??
          _getInheritedString(node, 'alignment-baseline'),
    );
    final baselineShift = _resolveBaselineShift(
      _getInheritedAttributeValue(node, 'baseline-shift'),
      metrics.fontSize,
    );
    final baselineRef = _resolveBaselineReference(
      dominantBaseline: dominantBaseline,
      metrics: metrics,
    );
    final shiftedBaselineY = baselineY - baselineShift;
    return shiftedBaselineY - baselineRef;
  }

  double _resolveTextPathCenterOffset({
    required SvgNode node,
    required _TextMeasure metrics,
  }) {
    final dominantBaseline = _resolveDominantBaseline(
      _getInheritedString(node, 'dominant-baseline') ??
          _getInheritedString(node, 'alignment-baseline'),
    );
    final baselineShift = _resolveBaselineShift(
      _getInheritedAttributeValue(node, 'baseline-shift'),
      metrics.fontSize,
    );
    final baselineRef = _resolveBaselineReference(
      dominantBaseline: dominantBaseline,
      metrics: metrics,
    );
    return -baselineRef - baselineShift + metrics.height / 2;
  }

  _TextDominantBaseline _resolveDominantBaseline(String? rawValue) {
    switch (rawValue?.trim().toLowerCase()) {
      case 'middle':
      case 'central':
        return _TextDominantBaseline.central;
      case 'text-before-edge':
      case 'before-edge':
      case 'hanging':
        return _TextDominantBaseline.textBeforeEdge;
      case 'text-after-edge':
      case 'after-edge':
      case 'ideographic':
        return _TextDominantBaseline.textAfterEdge;
      case 'alphabetic':
      default:
        return _TextDominantBaseline.alphabetic;
    }
  }

  double _resolveBaselineReference({
    required _TextDominantBaseline dominantBaseline,
    required _TextMeasure metrics,
  }) {
    return switch (dominantBaseline) {
      _TextDominantBaseline.alphabetic => metrics.alphabeticBaseline,
      _TextDominantBaseline.central => metrics.height / 2,
      _TextDominantBaseline.textBeforeEdge => 0.0,
      _TextDominantBaseline.textAfterEdge => metrics.height,
    };
  }

  double _resolveBaselineShift(Object? rawValue, double fontSize) {
    if (rawValue == null) {
      return 0.0;
    }
    if (rawValue is num) {
      return rawValue.toDouble().clamp(-4096.0, 4096.0);
    }
    final value = rawValue.toString().trim().toLowerCase();
    if (value.isEmpty || value == 'baseline') {
      return 0.0;
    }
    if (value == 'sub') {
      return -fontSize * 0.6;
    }
    if (value == 'super') {
      return fontSize * 0.6;
    }
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      return (fontSize * percent / 100.0).clamp(-4096.0, 4096.0);
    }
    final numeric = double.tryParse(value.replaceAll(RegExp(r'[a-z]+$'), ''));
    return (numeric ?? 0.0).clamp(-4096.0, 4096.0);
  }

  double _spacingAfterGlyphForHit({
    required String glyph,
    required bool isLast,
    required double letterSpacing,
    required double wordSpacing,
  }) {
    if (isLast) {
      return 0.0;
    }
    var spacing = letterSpacing;
    if (glyph == ' ' || glyph == '\u00A0') {
      spacing += wordSpacing;
    }
    return spacing;
  }

  _TextAnchor _resolveTextAnchor(SvgNode node) {
    final textAnchor = _getInheritedString(node, 'text-anchor')?.toLowerCase();
    switch (textAnchor) {
      case 'middle':
        return _TextAnchor.middle;
      case 'end':
        return _TextAnchor.end;
      case 'start':
      default:
        return _TextAnchor.start;
    }
  }

  double _parseTextPathStartOffset(SvgNode textPathNode, double pathLength) {
    final raw = textPathNode.getAttributeValue('startOffset');
    if (raw == null) {
      return 0.0;
    }

    if (raw is num) {
      return raw.toDouble().clamp(0.0, pathLength);
    }

    final value = raw.toString().trim();
    if (value.isEmpty) {
      return 0.0;
    }

    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      return (pathLength * percent / 100.0).clamp(0.0, pathLength);
    }

    return (double.tryParse(value) ?? 0.0).clamp(0.0, pathLength);
  }
}
