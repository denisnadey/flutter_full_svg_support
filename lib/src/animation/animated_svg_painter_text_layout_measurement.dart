part of 'animated_svg_painter.dart';

/// Text measurement and metrics utilities.
///
/// Contains methods for:
/// - Text length resolution and adjustment
/// - Text content extraction with whitespace handling
/// - Transform composition for nested text elements
/// - TextLength distribution across nested tspan children
extension AnimatedSvgPainterTextLayoutMeasurementExtension
    on AnimatedSvgPainter {
  /// Computes spacing after a glyph for textPath rendering.
  double _textPathSpacingAfterGlyph({
    required String glyph,
    required bool isLast,
    required _ResolvedTextStyle style,
  }) {
    if (isLast) return 0.0;
    var spacing = style.letterSpacing;
    if (glyph == ' ' || glyph == '\u00A0') spacing += style.wordSpacing;
    return spacing;
  }

  /// Resolves text top position from baseline reference.
  double _resolveTextTopFromBaseline({
    required ui.Paragraph paragraph,
    required _ResolvedTextStyle style,
    required double baselineY,
  }) {
    final baselineRef = _resolveBaselineReference(
      paragraph: paragraph,
      dominantBaseline: style.dominantBaseline,
      writingMode: style.writingMode,
    );
    final shiftedBaselineY = baselineY - style.baselineShift;
    return shiftedBaselineY - baselineRef;
  }

  /// Resolves textLength attribute value.
  double? _resolveTextLength(SvgNode node) {
    final value = node.getAttributeValue('textLength');
    if (value == null) return null;
    if (value is num) {
      final length = value.toDouble();
      return length > 0 ? length : null;
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  /// Resolves lengthAdjust attribute value.
  _SvgTextLengthAdjust _resolveLengthAdjust(SvgNode node) {
    final raw = node.getAttributeValue('lengthAdjust')?.toString().trim();
    if (raw == null || raw.isEmpty) return _SvgTextLengthAdjust.spacing;
    return raw.toLowerCase() == 'spacingandglyphs'
        ? _SvgTextLengthAdjust.spacingAndGlyphs
        : _SvgTextLengthAdjust.spacing;
  }

  /// Resolves textPath geometry from href reference.
  ui.Path? _resolveTextPathGeometry(SvgNode textPathNode) {
    final hrefId = _extractHrefId(textPathNode);
    if (hrefId == null || hrefId.isEmpty) return null;
    final referenced = document.root.findById(hrefId);
    if (referenced == null || referenced.tagName != 'path') return null;
    final path = _buildGeometryPath(referenced);
    if (path == null) return null;
    final transform = _buildTransformMatrixFromValue(
      referenced.getAttributeValue('transform'),
    );
    if (transform == null) return path;
    return path.transform(transform.storage);
  }

  /// Parses textPath startOffset attribute.
  double _parseTextPathStartOffset(SvgNode textPathNode, double pathLength) {
    final raw = textPathNode.getAttributeValue('startOffset');
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble().clamp(0.0, pathLength);
    final value = raw.toString().trim();
    if (value.isEmpty) return 0.0;
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) return 0.0;
      return (pathLength * percent / 100.0).clamp(0.0, pathLength);
    }
    return (double.tryParse(value) ?? 0.0).clamp(0.0, pathLength);
  }

  /// Extracts text content from a node with whitespace handling.
  String? _extractTextContent(SvgNode node) {
    final raw = _getString(node, '__text');
    if (raw == null) return null;
    final whiteSpace = _getInheritedString(node, 'white-space')?.toLowerCase();
    if (whiteSpace != null) {
      switch (whiteSpace) {
        case 'pre':
        case 'pre-wrap':
        case 'break-spaces':
          final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
          return preserved.isEmpty ? null : preserved;
        case 'pre-line':
          final preLine = raw.replaceAll(RegExp(r'[ \t]+'), ' ');
          return preLine.isEmpty ? null : preLine;
        case 'normal':
        case 'nowrap':
        default:
          final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
          return collapsed.isEmpty ? null : collapsed;
      }
    }
    final xmlSpace = _getInheritedString(node, 'xml:space')?.toLowerCase();
    if (xmlSpace == 'preserve') {
      final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
      return preserved.isEmpty ? null : preserved;
    }
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  /// Extracts text content with parent-aware whitespace normalization.
  String? _extractTextContentWithWhitespaceNormalization(
    SvgNode node,
    _ResolvedTextStyle? parentStyle,
  ) {
    final raw = _getString(node, '__text');
    if (raw == null) return null;
    final xmlSpace = _getInheritedString(node, 'xml:space')?.toLowerCase();
    final whiteSpace = _getInheritedString(node, 'white-space')?.toLowerCase();
    final preserveWhitespace =
        xmlSpace == 'preserve' ||
        whiteSpace == 'pre' ||
        whiteSpace == 'pre-wrap' ||
        whiteSpace == 'break-spaces';
    if (preserveWhitespace) {
      final preserved = raw.replaceAll('\n', ' ').replaceAll('\r', ' ');
      return preserved.isEmpty ? null : preserved;
    }
    final hasTextLikeChildren = node.children.any(
      (child) =>
          child.tagName == 'tspan' ||
          child.tagName == 'tref' ||
          child.tagName == 'textPath' ||
          child.tagName == 'bdo',
    );
    var normalized = raw.replaceAll(RegExp(r'\s+'), ' ');
    if (parentStyle == null) {
      normalized = hasTextLikeChildren
          ? normalized.replaceFirst(RegExp(r'^ +'), '')
          : normalized.trim();
    } else {
      if (normalized.trim().isEmpty && raw.contains(RegExp(r'\s'))) return ' ';
      if (!hasTextLikeChildren) {
        normalized = normalized.trimRight();
      }
    }
    return normalized.isEmpty ? null : normalized;
  }

  /// Computes the accumulated transform matrix for deeply nested tspan elements.
  ///
  /// Walks up from the current tspan to the root text element, composing all
  /// transform attributes. This ensures that per-character positions are
  /// resolved in the correct coordinate space when transforms are applied
  /// at multiple nesting levels.
  ///
  /// Performance optimization: Uses in-place matrix multiplication instead of
  /// creating new Matrix4 objects via multiplied(). Collects transforms during
  /// tree walk and composes in reverse order without intermediate allocations.
  Matrix4 _computeTextElementAccumulatedTransform(SvgNode node) {
    // Count transforms first to avoid List resizing
    int transformCount = 0;
    SvgNode? current = node;
    while (current != null) {
      if (current.getAttributeValue('transform') != null) {
        transformCount++;
      }
      if (current.tagName == 'text') break;
      current = current.parent;
    }

    // Early exit if no transforms found
    if (transformCount == 0) {
      return Matrix4.identity();
    }

    // Collect transforms into pre-sized list
    final transformStack = List<Matrix4>.filled(
      transformCount,
      Matrix4.identity(),
    );
    int insertIndex = 0;
    current = node;
    while (current != null) {
      final transformStr = current.getAttributeValue('transform');
      if (transformStr != null) {
        final matrix = _buildTransformMatrixFromValue(transformStr);
        if (matrix != null) {
          transformStack[insertIndex++] = matrix;
        }
      }
      if (current.tagName == 'text') break;
      current = current.parent;
    }

    // Compose transforms in reverse order (root to leaf) using in-place multiply.
    // Start with the root transform (last collected) and multiply in-place.
    final result = transformStack[insertIndex - 1].clone();
    for (int i = insertIndex - 2; i >= 0; i--) {
      result.multiply(transformStack[i]);
    }
    return result;
  }

  /// Transforms a point using the accumulated transform matrix.
  ui.Offset _transformPointForText(ui.Offset point, Matrix4 transform) {
    if (transform.isIdentity()) {
      return point;
    }
    // Use manual matrix multiplication for the transform
    final x = point.dx;
    final y = point.dy;
    final storage = transform.storage;
    final tx = storage[0] * x + storage[4] * y + storage[12];
    final ty = storage[1] * x + storage[5] * y + storage[13];
    return ui.Offset(tx, ty);
  }

  /// Computes the total text width for all tspan children of a text element.
  double _computeNestedTspanTotalWidth(
    SvgNode textNode,
    _ResolvedTextStyle parentStyle,
  ) {
    double totalWidth = 0.0;

    final directText = _extractTextContentWithWhitespaceNormalization(
      textNode,
      null,
    );
    if (directText != null && directText.isNotEmpty) {
      final paragraph = _buildTextParagraph(directText, parentStyle);
      totalWidth += paragraph.maxIntrinsicWidth;
    }

    for (final child in textNode.children) {
      if (child.tagName == 'tspan') {
        final childStyle = _resolveTextStyle(child, parentStyle: parentStyle);
        totalWidth += _computeNestedTspanTotalWidth(child, childStyle);
      }
    }

    return totalWidth;
  }

  /// Computes proportional textLength distribution for nested tspan elements.
  _TextLengthDistribution _computeTextLengthDistribution(
    SvgNode textNode,
    _ResolvedTextStyle style,
  ) {
    final targetLength = _resolveTextLength(textNode);
    if (targetLength == null || targetLength <= 0) {
      return const _TextLengthDistribution.none();
    }

    final naturalWidth = _computeNestedTspanTotalWidth(textNode, style);
    if (naturalWidth <= 0) {
      return const _TextLengthDistribution.none();
    }

    final lengthAdjust = _resolveLengthAdjust(textNode);

    if (lengthAdjust == _SvgTextLengthAdjust.spacing) {
      final totalChars = _countNestedCharacters(textNode);
      if (totalChars <= 1) {
        return const _TextLengthDistribution.none();
      }
      final extraSpacing = (targetLength - naturalWidth) / (totalChars - 1);
      return _TextLengthDistribution.spacing(extraSpacing);
    } else {
      final scaleFactor = targetLength / naturalWidth;
      return _TextLengthDistribution.scale(scaleFactor);
    }
  }

  /// Counts total grapheme clusters in text node and all nested tspan children.
  int _countNestedCharacters(SvgNode node) {
    int count = 0;

    final text = _extractTextContentWithWhitespaceNormalization(node, null);
    if (text != null && text.isNotEmpty) {
      count += text.runes.length;
    }

    for (final child in node.children) {
      if (child.tagName == 'tspan') {
        count += _countNestedCharacters(child);
      }
    }

    return count;
  }
}

/// Represents a text run within a multi-run paragraph.
class _MultiRunTextRun {
  const _MultiRunTextRun({
    required this.text,
    required this.style,
    required this.fontFeatures,
  });
  final String text;
  final _ResolvedTextStyle style;
  final List<ui.FontFeature> fontFeatures;
}

/// Distribution mode for textLength across nested tspan elements.
class _TextLengthDistribution {
  const _TextLengthDistribution.none()
    : mode = _TextLengthDistributionMode.none,
      value = 0.0;

  const _TextLengthDistribution.spacing(double extraSpacing)
    : mode = _TextLengthDistributionMode.spacing,
      value = extraSpacing;

  const _TextLengthDistribution.scale(double scaleFactor)
    : mode = _TextLengthDistributionMode.scale,
      value = scaleFactor;

  final _TextLengthDistributionMode mode;
  final double value;

  bool get isNone => mode == _TextLengthDistributionMode.none;
  bool get isSpacing => mode == _TextLengthDistributionMode.spacing;
  bool get isScale => mode == _TextLengthDistributionMode.scale;

  double get extraSpacing => isSpacing ? value : 0.0;
  double get scaleFactor => isScale ? value : 1.0;
}

enum _TextLengthDistributionMode { none, spacing, scale }
