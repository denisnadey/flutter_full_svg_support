part of 'animated_svg_painter.dart';

/// Text positioning utilities for baseline handling and bidi context.
///
/// Contains methods for:
/// - baseline-shift resolution
/// - Baseline reference computation
/// - Accumulated baseline offset calculation
/// - Bidirectional text context handling
extension AnimatedSvgPainterTextPositioningExtension on AnimatedSvgPainter {
  /// Resolves baseline-shift attribute value.
  /// Supports: baseline, sub, super, percentage, length values.
  /// Per SVG spec, percentage is relative to line-height (computed height of line box).
  double _resolveBaselineShift(
    Object? rawValue,
    double fontSize, {
    double? lineHeight,
  }) {
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
    // Subscript: shift down by a factor of font-size
    // Blink uses ~0.3em descent from baseline
    if (value == 'sub') {
      return -fontSize * 0.3;
    }
    // Superscript: shift up by a factor of font-size
    // Blink uses ~0.4em above baseline
    if (value == 'super') {
      return fontSize * 0.4;
    }
    // Percentage: relative to line-height (or 1.2 * fontSize as default)
    if (value.endsWith('%')) {
      final percent = double.tryParse(value.substring(0, value.length - 1));
      if (percent == null) {
        return 0.0;
      }
      // Use line-height if provided, otherwise default to 1.2 * fontSize
      final effectiveLineHeight = lineHeight ?? (fontSize * 1.2);
      return (effectiveLineHeight * percent / 100.0).clamp(-4096.0, 4096.0);
    }
    // em units: relative to font-size
    if (value.endsWith('em')) {
      final em = double.tryParse(value.substring(0, value.length - 2));
      if (em != null) {
        return (fontSize * em).clamp(-4096.0, 4096.0);
      }
      return 0.0;
    }
    // ex units: relative to x-height (~0.5 * font-size)
    if (value.endsWith('ex')) {
      final ex = double.tryParse(value.substring(0, value.length - 2));
      if (ex != null) {
        return (fontSize * 0.5 * ex).clamp(-4096.0, 4096.0);
      }
      return 0.0;
    }
    // Plain number or px: treat as user units
    final numeric = double.tryParse(value.replaceAll(RegExp(r'[a-z]+$'), ''));
    return (numeric ?? 0.0).clamp(-4096.0, 4096.0);
  }

  /// Resolves baseline offset from paragraph metrics.
  /// Returns the y-offset from the paragraph top to the specified baseline.
  double _resolveBaselineReference({
    required ui.Paragraph paragraph,
    required _SvgDominantBaseline dominantBaseline,
    _SvgWritingMode writingMode = _SvgWritingMode.horizontalTb,
  }) {
    // Get font metrics from paragraph
    final height = paragraph.height;
    final alphabeticBaseline = paragraph.alphabeticBaseline;
    final ideographicBaseline = paragraph.ideographicBaseline;

    // Calculate approximate ascent from alphabetic baseline
    // alphabeticBaseline is the distance from top to baseline
    final ascent = alphabeticBaseline;

    // Approximate x-height as ~50% of ascent (typical for Latin fonts)
    final xHeight = ascent * 0.5;

    // For vertical writing modes, adjust baseline model
    if (writingMode != _SvgWritingMode.horizontalTb) {
      // In vertical writing, central baseline is most common
      return switch (dominantBaseline) {
        _SvgDominantBaseline.alphabetic => height / 2,
        _SvgDominantBaseline.central => height / 2,
        _SvgDominantBaseline.middle => height / 2,
        _SvgDominantBaseline.textBeforeEdge => 0.0,
        _SvgDominantBaseline.textAfterEdge => height,
        _SvgDominantBaseline.hanging => ascent * 0.8,
        _SvgDominantBaseline.mathematical => height / 2,
        _SvgDominantBaseline.ideographic => ideographicBaseline,
      };
    }

    return switch (dominantBaseline) {
      _SvgDominantBaseline.alphabetic => alphabeticBaseline,
      _SvgDominantBaseline.central => height / 2,
      _SvgDominantBaseline.middle => height / 2,
      _SvgDominantBaseline.textBeforeEdge => 0.0,
      _SvgDominantBaseline.textAfterEdge => height,
      // Hanging baseline: approximately 80% of ascent from top
      // Used for Indic scripts where the main stroke hangs from the top
      _SvgDominantBaseline.hanging => ascent * 0.8,
      // Mathematical baseline: centered on math operators
      // Typically at x-height / 2 + some offset (~50% of x-height above baseline)
      _SvgDominantBaseline.mathematical => alphabeticBaseline - xHeight * 0.5,
      // Ideographic baseline: at the bottom of the ideographic em box
      // Use the ideographicBaseline if available, else approximate
      _SvgDominantBaseline.ideographic => ideographicBaseline,
    };
  }

  /// Context for accumulating baseline offsets through nested text elements.
  ///
  /// Tracks font-size, dominant-baseline, alignment-baseline, baseline-shift,
  /// and writing-mode at each nesting level to correctly compute cumulative
  /// baseline offsets for deeply nested tspan elements.
  _BaselineContext _buildBaselineContext(SvgNode node) {
    final ancestors = <_BaselineAncestorInfo>[];
    SvgNode? current = node;

    // Walk up to root text element, collecting style info at each level
    while (current != null) {
      final tagName = current.tagName;
      if (tagName == 'text' || tagName == 'tspan' || tagName == 'textPath') {
        final fontSize =
            _getNodeOwnNumber(current, 'font-size') ??
            (ancestors.isEmpty ? 16.0 : null);
        final dominantBaseline = _getNodeOwnString(
          current,
          'dominant-baseline',
        );
        final alignmentBaseline = _getNodeOwnString(
          current,
          'alignment-baseline',
        );
        final baselineShift = _getNodeOwnAttributeValue(
          current,
          'baseline-shift',
        );
        final writingMode = _getNodeOwnString(current, 'writing-mode');

        ancestors.add(
          _BaselineAncestorInfo(
            fontSize: fontSize,
            dominantBaseline: dominantBaseline,
            alignmentBaseline: alignmentBaseline,
            baselineShift: baselineShift,
            writingMode: writingMode,
          ),
        );

        // Stop at root text element
        if (tagName == 'text') {
          break;
        }
      }
      current = current.parent;
    }

    // Reverse to get root-to-leaf order
    return _BaselineContext(ancestors.reversed.toList());
  }

  /// Gets the node's own attribute value (not inherited).
  Object? _getNodeOwnAttributeValue(SvgNode node, String name) {
    return node.getAttributeValue(name);
  }

  /// Gets the node's own string attribute value (not inherited).
  String? _getNodeOwnString(SvgNode node, String name) {
    final value = node.getAttributeValue(name);
    if (value == null) return null;
    return value.toString();
  }

  /// Gets the node's own number attribute value (not inherited).
  double? _getNodeOwnNumber(SvgNode node, String name) {
    final value = node.getAttributeValue(name);
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(
      value.toString().trim().replaceAll(RegExp(r'[a-zA-Z%]+$'), ''),
    );
  }

  /// Calculates accumulated baseline offset through the ancestor chain.
  ///
  /// This method computes the total Y offset (or X offset for vertical text)
  /// needed to align deeply nested text elements correctly. It accounts for:
  /// - Font-size changes at each nesting level
  /// - dominant-baseline transitions
  /// - alignment-baseline at each level
  /// - baseline-shift accumulation
  /// - writing-mode axis changes
  ///
  /// Returns a [_AccumulatedBaselineOffset] containing both the offset value
  /// and the axis it should be applied on.
  _AccumulatedBaselineOffset _resolveAccumulatedBaselineOffset({
    required SvgNode node,
    required _ResolvedTextStyle leafStyle,
  }) {
    final context = _buildBaselineContext(node);
    if (context.ancestors.length < 2) {
      // No nesting or single level - no accumulated offset needed
      return const _AccumulatedBaselineOffset(yOffset: 0.0, xOffset: 0.0);
    }

    double accumulatedYOffset = 0.0;
    double accumulatedXOffset = 0.0;

    // Track running values through the chain
    double runningFontSize = 16.0;
    _SvgDominantBaseline runningDominantBaseline =
        _SvgDominantBaseline.alphabetic;
    _SvgWritingMode runningWritingMode = _SvgWritingMode.horizontalTb;

    for (int i = 0; i < context.ancestors.length; i++) {
      final ancestor = context.ancestors[i];
      // Note: isLast could be used for special end-of-chain handling if needed

      // Resolve this level's font size
      final levelFontSize = ancestor.fontSize ?? runningFontSize;

      // Resolve this level's dominant baseline
      final levelDominantBaseline = ancestor.dominantBaseline != null
          ? _resolveDominantBaseline(ancestor.dominantBaseline)
          : runningDominantBaseline;

      // Resolve this level's writing mode
      final levelWritingMode = ancestor.writingMode != null
          ? _resolveWritingMode(ancestor.writingMode)
          : runningWritingMode;

      // Check for writing-mode transition
      final hasWritingModeTransition = runningWritingMode != levelWritingMode;

      // Calculate font-size based baseline offset if font size changes
      if (i > 0 &&
          ancestor.fontSize != null &&
          ancestor.fontSize != runningFontSize) {
        final parentFontSize = runningFontSize;
        final childFontSize = levelFontSize;

        // Calculate baseline offset for this font size transition
        final offset = _calculateFontSizeBaselineOffset(
          parentFontSize: parentFontSize,
          childFontSize: childFontSize,
          parentBaseline: runningDominantBaseline,
          childBaseline: levelDominantBaseline,
        );

        // Apply offset to correct axis based on writing mode
        if (hasWritingModeTransition) {
          // Writing mode changed - project onto new axis
          if (levelWritingMode == _SvgWritingMode.horizontalTb) {
            // Transitioning to horizontal - Y axis is baseline
            accumulatedYOffset += offset;
          } else {
            // Transitioning to vertical - X axis is baseline
            accumulatedXOffset += offset;
          }
        } else if (levelWritingMode == _SvgWritingMode.horizontalTb) {
          accumulatedYOffset += offset;
        } else {
          accumulatedXOffset += offset;
        }
      }

      // Calculate dominant-baseline transition offset
      if (i > 0 && levelDominantBaseline != runningDominantBaseline) {
        final offset = _calculateBaselineTransitionOffset(
          fromBaseline: runningDominantBaseline,
          toBaseline: levelDominantBaseline,
          fontSize: levelFontSize,
        );

        if (levelWritingMode == _SvgWritingMode.horizontalTb) {
          accumulatedYOffset += offset;
        } else {
          accumulatedXOffset += offset;
        }
      }

      // Handle alignment-baseline (how child aligns to parent's dominant-baseline)
      if (i > 0 && ancestor.alignmentBaseline != null) {
        final alignmentBaseline = _resolveDominantBaseline(
          ancestor.alignmentBaseline,
        );
        if (alignmentBaseline != runningDominantBaseline) {
          final offset = _calculateAlignmentBaselineOffset(
            parentDominantBaseline: runningDominantBaseline,
            childAlignmentBaseline: alignmentBaseline,
            fontSize: levelFontSize,
          );

          if (levelWritingMode == _SvgWritingMode.horizontalTb) {
            accumulatedYOffset += offset;
          } else {
            accumulatedXOffset += offset;
          }
        }
      }

      // Accumulate baseline-shift
      if (ancestor.baselineShift != null) {
        final shift = _resolveBaselineShift(
          ancestor.baselineShift,
          levelFontSize,
        );

        if (levelWritingMode == _SvgWritingMode.horizontalTb) {
          // In horizontal mode, positive shift moves up (negative Y)
          accumulatedYOffset -= shift;
        } else {
          // In vertical mode, positive shift moves to the start direction
          accumulatedXOffset -= shift;
        }
      }

      // Update running values for next iteration
      runningFontSize = levelFontSize;
      runningDominantBaseline = levelDominantBaseline;
      runningWritingMode = levelWritingMode;
    }

    return _AccumulatedBaselineOffset(
      yOffset: accumulatedYOffset,
      xOffset: accumulatedXOffset,
    );
  }

  /// Calculates baseline offset due to font-size change between parent and child.
  double _calculateFontSizeBaselineOffset({
    required double parentFontSize,
    required double childFontSize,
    required _SvgDominantBaseline parentBaseline,
    required _SvgDominantBaseline childBaseline,
  }) {
    // For alphabetic baseline (most common), the offset is the difference
    // in baseline positions relative to the top of the em-box.
    // Alphabetic baseline is typically at ~80% of font-size from top.
    const baselineRatio = 0.8;

    final parentBaselineY = parentFontSize * baselineRatio;
    final childBaselineY = childFontSize * baselineRatio;

    // Return offset to align child baseline with parent baseline
    return parentBaselineY - childBaselineY;
  }

  /// Calculates offset for transitioning between different baseline types.
  double _calculateBaselineTransitionOffset({
    required _SvgDominantBaseline fromBaseline,
    required _SvgDominantBaseline toBaseline,
    required double fontSize,
  }) {
    // Calculate baseline positions as ratios of font-size
    final fromPos = _getBaselinePosition(fromBaseline, fontSize);
    final toPos = _getBaselinePosition(toBaseline, fontSize);
    return fromPos - toPos;
  }

  /// Gets the position of a baseline as distance from top of em-box.
  double _getBaselinePosition(_SvgDominantBaseline baseline, double fontSize) {
    // These ratios are approximations based on typical font metrics
    return switch (baseline) {
      _SvgDominantBaseline.alphabetic => fontSize * 0.8,
      _SvgDominantBaseline.central => fontSize * 0.5,
      _SvgDominantBaseline.middle => fontSize * 0.5,
      _SvgDominantBaseline.textBeforeEdge => 0.0,
      _SvgDominantBaseline.textAfterEdge => fontSize,
      _SvgDominantBaseline.hanging => fontSize * 0.15,
      _SvgDominantBaseline.mathematical => fontSize * 0.4,
      _SvgDominantBaseline.ideographic => fontSize * 0.95,
    };
  }

  /// Calculates offset for alignment-baseline relative to parent's dominant-baseline.
  double _calculateAlignmentBaselineOffset({
    required _SvgDominantBaseline parentDominantBaseline,
    required _SvgDominantBaseline childAlignmentBaseline,
    required double fontSize,
  }) {
    // alignment-baseline specifies which baseline of the child should align
    // with the parent's dominant-baseline
    final parentPos = _getBaselinePosition(parentDominantBaseline, fontSize);
    final childAlignPos = _getBaselinePosition(
      childAlignmentBaseline,
      fontSize,
    );
    return parentPos - childAlignPos;
  }

  /// Resolves baseline offset for mixed font-size rendering.
  ///
  /// This is a convenience method that extracts just the Y offset for
  /// horizontal text rendering, which is the most common case.
  double resolveMixedBaselineOffset({
    required SvgNode node,
    required _ResolvedTextStyle currentStyle,
    _ResolvedTextStyle? parentStyle,
  }) {
    // Use accumulated offset for deep nesting support
    final accumulated = _resolveAccumulatedBaselineOffset(
      node: node,
      leafStyle: currentStyle,
    );

    // For horizontal text, return Y offset
    // For vertical text, return X offset
    if (currentStyle.writingMode == _SvgWritingMode.horizontalTb) {
      return accumulated.yOffset;
    } else {
      return accumulated.xOffset;
    }
  }

  /// Builds the bidirectional text context for a text element.
  ///
  /// This traverses the element hierarchy and builds a context that tracks
  /// direction changes at each nesting level.
  _BidiContext _buildBidiContext(SvgNode node) {
    // Find root text element to get base direction
    SvgNode? root = node;
    while (root != null && root.tagName != 'text') {
      root = root.parent;
    }

    final baseDirection = _resolveTextDirection(
      root != null ? _getInheritedString(root, 'direction') : null,
    );

    // Build levels from root to current node
    final levels = <_BidiLevel>[];
    final pathToNode = <SvgNode>[];

    // Collect path from root to current node
    SvgNode? current = node;
    while (current != null && current != root) {
      pathToNode.insert(0, current);
      current = current.parent;
    }

    // Build bidi levels for each element in path
    for (final element in pathToNode) {
      final direction = _resolveTextDirection(
        element.getAttributeValue('direction')?.toString(),
      );
      final unicodeBidi = _resolveUnicodeBidi(
        element.getAttributeValue('unicode-bidi')?.toString(),
      );
      final isIsolate =
          unicodeBidi == 'isolate' || unicodeBidi == 'isolate-override';

      levels.add(
        _BidiLevel(
          direction: direction,
          unicodeBidi: unicodeBidi,
          isIsolate: isIsolate,
        ),
      );
    }

    return _BidiContext(baseDirection: baseDirection, levels: levels);
  }

  /// Resolves the effective text direction for a nested element.
  ///
  /// Handles the case where parent has direction="rtl" but child has
  /// LTR content, respecting the Unicode Bidi Algorithm.
  ui.TextDirection _resolveEffectiveBidiDirection(
    SvgNode node,
    _ResolvedTextStyle? parentStyle,
  ) {
    // Get explicit direction on this node
    final explicitDirection = node.getAttributeValue('direction');
    if (explicitDirection != null) {
      return _resolveTextDirection(explicitDirection.toString());
    }

    // Inherit from parent style
    if (parentStyle != null) {
      return parentStyle.textDirection;
    }

    // Fall back to inherited direction
    return _resolveTextDirection(_getInheritedString(node, 'direction'));
  }
}

/// Information about a single ancestor in the baseline calculation chain.
class _BaselineAncestorInfo {
  const _BaselineAncestorInfo({
    this.fontSize,
    this.dominantBaseline,
    this.alignmentBaseline,
    this.baselineShift,
    this.writingMode,
  });

  final double? fontSize;
  final String? dominantBaseline;
  final String? alignmentBaseline;
  final Object? baselineShift;
  final String? writingMode;
}

/// Context containing the full ancestor chain for baseline calculation.
class _BaselineContext {
  const _BaselineContext(this.ancestors);

  /// Ancestors from root (text element) to leaf (deepest tspan).
  final List<_BaselineAncestorInfo> ancestors;
}

/// Accumulated baseline offset with separate X and Y components.
///
/// X offset is used for vertical text baseline adjustments.
/// Y offset is used for horizontal text baseline adjustments.
class _AccumulatedBaselineOffset {
  const _AccumulatedBaselineOffset({
    required this.yOffset,
    required this.xOffset,
  });

  final double yOffset;
  final double xOffset;
}

/// Handles bidirectional text direction inheritance in complex hierarchies.
///
/// When parent text element has direction="rtl" but inner tspan elements
/// contain LTR content (or vice versa), this class tracks the effective
/// direction at each nesting level.
class _BidiContext {
  const _BidiContext({required this.baseDirection, required this.levels});

  /// The direction specified on the root text element.
  final ui.TextDirection baseDirection;

  /// Stack of direction levels for nested elements.
  /// Each entry represents a tspan's effective direction.
  final List<_BidiLevel> levels;

  /// Gets the current effective direction at this nesting level.
  ui.TextDirection get currentDirection =>
      levels.isEmpty ? baseDirection : levels.last.direction;

  /// Whether current position is a direction boundary (change from parent).
  bool get isDirectionBoundary {
    if (levels.isEmpty) return false;
    if (levels.length == 1) return levels.first.direction != baseDirection;
    return levels.last.direction != levels[levels.length - 2].direction;
  }

  /// Creates a new context with an added nesting level.
  _BidiContext withLevel(_BidiLevel level) {
    return _BidiContext(
      baseDirection: baseDirection,
      levels: [...levels, level],
    );
  }
}

/// A single level in the bidirectional text context.
class _BidiLevel {
  const _BidiLevel({
    required this.direction,
    required this.unicodeBidi,
    required this.isIsolate,
  });

  /// The text direction at this level.
  final ui.TextDirection direction;

  /// The unicode-bidi property value.
  final String? unicodeBidi;

  /// Whether this level is isolated from surrounding text.
  final bool isIsolate;
}
