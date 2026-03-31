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

  /// Checks if the node is a BDO (bi-directional override) element.
  bool _bidiIsBdoElement(SvgNode node) {
    return node.tagName == 'bdo';
  }

  /// Resolves direction for BDO elements, handling dir="auto".
  ///
  /// For BDO elements:
  /// - dir="ltr" forces LTR direction
  /// - dir="rtl" forces RTL direction
  /// - dir="auto" determines direction from first strong character
  ui.TextDirection _bidiResolveBdoDirection(
    SvgNode node,
    String? textContent,
  ) {
    final dirAttr = node.getAttributeValue('dir')?.toString().toLowerCase();

    if (dirAttr == 'auto' && textContent != null) {
      // Determine direction from first strong directional character
      return _bidiDetectFirstStrongDirection(textContent);
    }

    if (dirAttr == 'rtl') {
      return ui.TextDirection.rtl;
    }

    // Default to LTR for dir="ltr" or any other value
    return ui.TextDirection.ltr;
  }

  /// Detects direction from the first strong directional character in text.
  ///
  /// Per UAX #9 (Unicode Bidi Algorithm), strong directional characters are:
  /// - L (Left-to-Right): Latin, Greek, Cyrillic, etc.
  /// - R (Right-to-Left): Hebrew
  /// - AL (Arabic Letter): Arabic, Syriac, Thaana
  ui.TextDirection _bidiDetectFirstStrongDirection(String text) {
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);

      // RTL: Hebrew range (0x0590-0x05FF)
      if (codeUnit >= 0x0590 && codeUnit <= 0x05FF) {
        return ui.TextDirection.rtl;
      }

      // RTL: Arabic range (0x0600-0x06FF)
      if (codeUnit >= 0x0600 && codeUnit <= 0x06FF) {
        return ui.TextDirection.rtl;
      }

      // RTL: Arabic Supplement (0x0750-0x077F)
      if (codeUnit >= 0x0750 && codeUnit <= 0x077F) {
        return ui.TextDirection.rtl;
      }

      // RTL: Arabic Extended-A (0x08A0-0x08FF)
      if (codeUnit >= 0x08A0 && codeUnit <= 0x08FF) {
        return ui.TextDirection.rtl;
      }

      // RTL: Syriac (0x0700-0x074F)
      if (codeUnit >= 0x0700 && codeUnit <= 0x074F) {
        return ui.TextDirection.rtl;
      }

      // RTL: Thaana (0x0780-0x07BF)
      if (codeUnit >= 0x0780 && codeUnit <= 0x07BF) {
        return ui.TextDirection.rtl;
      }

      // LTR: Basic Latin letters (A-Z, a-z)
      if ((codeUnit >= 0x0041 && codeUnit <= 0x005A) ||
          (codeUnit >= 0x0061 && codeUnit <= 0x007A)) {
        return ui.TextDirection.ltr;
      }

      // LTR: Latin Extended-A and Extended-B
      if (codeUnit >= 0x0100 && codeUnit <= 0x024F) {
        return ui.TextDirection.ltr;
      }

      // LTR: Greek (0x0370-0x03FF)
      if (codeUnit >= 0x0370 && codeUnit <= 0x03FF) {
        return ui.TextDirection.ltr;
      }

      // LTR: Cyrillic (0x0400-0x04FF)
      if (codeUnit >= 0x0400 && codeUnit <= 0x04FF) {
        return ui.TextDirection.ltr;
      }
    }

    // Default to LTR if no strong character found
    return ui.TextDirection.ltr;
  }

  /// Resolves the unicode-bidi behavior considering direction interaction.
  ///
  /// Handles all unicode-bidi values:
  /// - normal: element doesn't affect bidi
  /// - embed: opens embedded level of bidi
  /// - isolate: isolates the content from surrounding bidi context
  /// - bidi-override: overrides bidi algorithm, all chars get explicit direction
  /// - isolate-override: combines isolate and override
  /// - plaintext: paragraph direction from first strong character
  _BidiLevel _bidiResolveUnicodeBidiInteraction(
    SvgNode node,
    ui.TextDirection inheritedDirection,
  ) {
    final unicodeBidi = node.getAttributeValue('unicode-bidi')?.toString();
    final directionAttr = node.getAttributeValue('direction')?.toString();
    final isBdo = _bidiIsBdoElement(node);

    // Resolve direction
    ui.TextDirection direction = inheritedDirection;
    if (directionAttr != null) {
      direction = _resolveTextDirection(directionAttr);
    }

    // Determine bidi mode
    final bidiMode = unicodeBidi?.toLowerCase().trim() ?? 'normal';

    bool isIsolate = false;
    bool isOverride = false;

    switch (bidiMode) {
      case 'embed':
        // Opens embedding level, inherits direction or uses explicit
        break;

      case 'isolate':
        isIsolate = true;
        break;

      case 'bidi-override':
        isOverride = true;
        break;

      case 'isolate-override':
        isIsolate = true;
        isOverride = true;
        break;

      case 'plaintext':
        // Direction determined from first strong character
        isIsolate = true;
        final text = _extractTextContent(node);
        if (text != null) {
          direction = _bidiDetectFirstStrongDirection(text);
        }
        break;

      case 'normal':
      default:
        // No special bidi behavior
        break;
    }

    // BDO elements always force override
    if (isBdo) {
      isOverride = true;
    }

    return _BidiLevel(
      direction: direction,
      unicodeBidi: unicodeBidi,
      isIsolate: isIsolate,
      isOverride: isOverride,
      isBdo: isBdo,
    );
  }

  /// Segments mixed-direction text into runs for proper visual reordering.
  ///
  /// This implements a simplified Unicode Bidi Algorithm (UBA) for SVG text.
  /// Each run has a consistent direction and can be positioned independently.
  List<_BidiTextRun> _bidiSegmentMixedDirectionText(
    String text,
    ui.TextDirection baseDirection, {
    bool isOverride = false,
  }) {
    if (text.isEmpty) return [];

    // If override is active, all text is forced to base direction
    if (isOverride) {
      return [
        _BidiTextRun(
          text: text,
          direction: baseDirection,
          logicalStart: 0,
          logicalEnd: text.length,
          visualOrder: 0,
          isOverridden: true,
        ),
      ];
    }

    final runs = <_BidiTextRun>[];
    int runStart = 0;
    ui.TextDirection? currentDirection;
    int visualOrder = 0;

    for (int i = 0; i < text.length; i++) {
      final charDirection = _bidiGetCharacterDirection(text.codeUnitAt(i));
      final effectiveDirection = charDirection ?? baseDirection;

      if (currentDirection == null) {
        currentDirection = effectiveDirection;
      } else if (effectiveDirection != currentDirection &&
          charDirection != null) {
        // Direction change, close current run
        runs.add(
          _BidiTextRun(
            text: text.substring(runStart, i),
            direction: currentDirection,
            logicalStart: runStart,
            logicalEnd: i,
            visualOrder: visualOrder++,
          ),
        );
        runStart = i;
        currentDirection = effectiveDirection;
      }
    }

    // Add final run
    if (runStart < text.length) {
      runs.add(
        _BidiTextRun(
          text: text.substring(runStart),
          direction: currentDirection ?? baseDirection,
          logicalStart: runStart,
          logicalEnd: text.length,
          visualOrder: visualOrder,
        ),
      );
    }

    // Reorder runs for visual display
    return _bidiReorderRunsForDisplay(runs, baseDirection);
  }

  /// Gets the directional character type for a code unit.
  ///
  /// Returns null for neutral characters (numbers, spaces, punctuation).
  ui.TextDirection? _bidiGetCharacterDirection(int codeUnit) {
    // RTL: Hebrew (0x0590-0x05FF)
    if (codeUnit >= 0x0590 && codeUnit <= 0x05FF) {
      return ui.TextDirection.rtl;
    }

    // RTL: Arabic (0x0600-0x06FF)
    if (codeUnit >= 0x0600 && codeUnit <= 0x06FF) {
      return ui.TextDirection.rtl;
    }

    // RTL: Arabic Supplement, Extended, Syriac, Thaana
    if ((codeUnit >= 0x0700 && codeUnit <= 0x08FF)) {
      return ui.TextDirection.rtl;
    }

    // LTR: Latin (A-Z, a-z)
    if ((codeUnit >= 0x0041 && codeUnit <= 0x005A) ||
        (codeUnit >= 0x0061 && codeUnit <= 0x007A)) {
      return ui.TextDirection.ltr;
    }

    // LTR: Extended Latin
    if (codeUnit >= 0x0100 && codeUnit <= 0x024F) {
      return ui.TextDirection.ltr;
    }

    // LTR: Greek, Cyrillic
    if (codeUnit >= 0x0370 && codeUnit <= 0x04FF) {
      return ui.TextDirection.ltr;
    }

    // Neutral (numbers, punctuation, spaces)
    return null;
  }

  /// Reorders bidi text runs for visual display based on base direction.
  ///
  /// In LTR base: LTR runs stay in place, RTL runs are reversed within their sequence
  /// In RTL base: RTL runs stay in place, LTR runs are reversed within their sequence
  List<_BidiTextRun> _bidiReorderRunsForDisplay(
    List<_BidiTextRun> runs,
    ui.TextDirection baseDirection,
  ) {
    if (runs.length <= 1) return runs;

    // Create a copy with updated visual orders
    final reordered = <_BidiTextRun>[];
    int visualOrder = 0;

    if (baseDirection == ui.TextDirection.ltr) {
      // For LTR base, RTL runs appear in reverse logical order
      for (int i = 0; i < runs.length; i++) {
        final run = runs[i];
        reordered.add(
          _BidiTextRun(
            text: run.text,
            direction: run.direction,
            logicalStart: run.logicalStart,
            logicalEnd: run.logicalEnd,
            visualOrder: visualOrder++,
            isOverridden: run.isOverridden,
          ),
        );
      }
    } else {
      // For RTL base, process runs in reverse for visual order
      for (int i = runs.length - 1; i >= 0; i--) {
        final run = runs[i];
        reordered.add(
          _BidiTextRun(
            text: run.text,
            direction: run.direction,
            logicalStart: run.logicalStart,
            logicalEnd: run.logicalEnd,
            visualOrder: visualOrder++,
            isOverridden: run.isOverridden,
          ),
        );
      }
    }

    // Sort by visual order for rendering
    reordered.sort((a, b) => a.visualOrder.compareTo(b.visualOrder));
    return reordered;
  }

  /// Maps a logical position to visual position for hit-testing in mixed-direction text.
  ///
  /// This is essential for correct cursor placement when clicking on
  /// mixed RTL/LTR text.
  _BidiPositionMapping _bidiMapLogicalToVisualPosition(
    int logicalIndex,
    List<_BidiTextRun> runs,
  ) {
    // Find the run containing this logical position
    for (final run in runs) {
      if (logicalIndex >= run.logicalStart && logicalIndex < run.logicalEnd) {
        // Calculate offset within run
        final offsetInRun = logicalIndex - run.logicalStart;

        // For RTL runs, visual position is reversed within the run
        int visualOffset;
        if (run.direction == ui.TextDirection.rtl) {
          visualOffset = (run.logicalEnd - run.logicalStart - 1) - offsetInRun;
        } else {
          visualOffset = offsetInRun;
        }

        // Calculate cumulative visual position
        int visualBase = 0;
        for (final r in runs) {
          if (r.visualOrder < run.visualOrder) {
            visualBase += r.logicalEnd - r.logicalStart;
          }
        }

        return _BidiPositionMapping(
          logicalIndex: logicalIndex,
          visualIndex: visualBase + visualOffset,
          direction: run.direction,
          isAtRunBoundary:
              offsetInRun == 0 ||
              offsetInRun == (run.logicalEnd - run.logicalStart - 1),
        );
      }
    }

    // Position is beyond all runs, return end position
    int totalLength = 0;
    for (final run in runs) {
      totalLength += run.logicalEnd - run.logicalStart;
    }

    return _BidiPositionMapping(
      logicalIndex: logicalIndex,
      visualIndex: totalLength,
      direction: runs.isNotEmpty ? runs.last.direction : ui.TextDirection.ltr,
      isAtRunBoundary: true,
    );
  }

  /// Maps a visual position back to logical position for selection.
  ///
  /// Inverse of [_bidiMapLogicalToVisualPosition].
  _BidiPositionMapping _bidiMapVisualToLogicalPosition(
    int visualIndex,
    List<_BidiTextRun> runs,
  ) {
    // Sort runs by visual order
    final sortedRuns = List<_BidiTextRun>.from(runs)
      ..sort((a, b) => a.visualOrder.compareTo(b.visualOrder));

    int currentVisualPos = 0;
    for (final run in sortedRuns) {
      final runLength = run.logicalEnd - run.logicalStart;

      if (visualIndex >= currentVisualPos &&
          visualIndex < currentVisualPos + runLength) {
        // Position is within this run
        final offsetInRun = visualIndex - currentVisualPos;

        // For RTL runs, logical position is reversed
        int logicalOffset;
        if (run.direction == ui.TextDirection.rtl) {
          logicalOffset = (runLength - 1) - offsetInRun;
        } else {
          logicalOffset = offsetInRun;
        }

        return _BidiPositionMapping(
          logicalIndex: run.logicalStart + logicalOffset,
          visualIndex: visualIndex,
          direction: run.direction,
          isAtRunBoundary: offsetInRun == 0 || offsetInRun == runLength - 1,
        );
      }

      currentVisualPos += runLength;
    }

    // Beyond all runs
    return _BidiPositionMapping(
      logicalIndex: runs.isNotEmpty ? runs.last.logicalEnd : 0,
      visualIndex: visualIndex,
      direction: runs.isNotEmpty ? runs.last.direction : ui.TextDirection.ltr,
      isAtRunBoundary: true,
    );
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
    this.isOverride = false,
    this.isBdo = false,
  });

  /// The text direction at this level.
  final ui.TextDirection direction;

  /// The unicode-bidi property value.
  final String? unicodeBidi;

  /// Whether this level is isolated from surrounding text.
  final bool isIsolate;

  /// Whether this level overrides the bidi algorithm.
  final bool isOverride;

  /// Whether this level comes from a <bdo> element.
  final bool isBdo;
}

/// Represents a text run with resolved bidi properties.
class _BidiTextRun {
  const _BidiTextRun({
    required this.text,
    required this.direction,
    required this.logicalStart,
    required this.logicalEnd,
    required this.visualOrder,
    this.isOverridden = false,
  });

  /// The text content of this run.
  final String text;

  /// The resolved direction for this run.
  final ui.TextDirection direction;

  /// Starting index in the logical (source) order.
  final int logicalStart;

  /// Ending index (exclusive) in the logical order.
  final int logicalEnd;

  /// The visual order index (for reordering).
  final int visualOrder;

  /// Whether bidi-override was applied to this run.
  final bool isOverridden;
}

/// Result of logical-to-visual position mapping for hit-testing.
class _BidiPositionMapping {
  const _BidiPositionMapping({
    required this.logicalIndex,
    required this.visualIndex,
    required this.direction,
    required this.isAtRunBoundary,
  });

  /// Position in logical (source) order.
  final int logicalIndex;

  /// Position in visual (rendered) order.
  final int visualIndex;

  /// Direction at this position.
  final ui.TextDirection direction;

  /// Whether this position is at a direction boundary.
  final bool isAtRunBoundary;
}

/// Detected script type for text shaping.
enum _ScriptType {
  /// Latin, Greek, Cyrillic and other simple LTR scripts.
  latin,

  /// Arabic script (RTL, requires contextual shaping).
  arabic,

  /// Hebrew script (RTL).
  hebrew,

  /// Thai script (requires cluster-aware segmentation).
  thai,

  /// Devanagari script (requires cluster-aware segmentation).
  devanagari,

  /// CJK (Chinese, Japanese, Korean) scripts.
  cjk,

  /// Bengali script (requires cluster-aware segmentation).
  bengali,

  /// Tamil script (requires cluster-aware segmentation).
  tamil,

  /// Other scripts (default handling).
  other,
}

/// Unicode normalization and complex script support utilities.
///
/// Provides NFC normalization per SVG spec and complex script detection
/// for proper text rendering with combining marks and diacritics.
extension AnimatedSvgPainterUnicodeExtension on AnimatedSvgPainter {
  /// Normalizes text to NFC (Canonical Decomposition, followed by Canonical Composition).
  ///
  /// Per SVG spec, text content should be normalized to NFC before rendering.
  /// This ensures that composed characters (like 'é') and decomposed sequences
  /// (like 'e' + combining acute accent) are rendered identically.
  String _normalizeTextToNFC(String text) {
    if (text.isEmpty) return text;

    // Check if normalization is needed (contains combining marks or decomposed chars)
    if (!_needsNormalization(text)) return text;

    // Perform NFC normalization
    return _applyNFCNormalization(text);
  }

  /// Checks if the text contains characters that may need NFC normalization.
  bool _needsNormalization(String text) {
    for (final codeUnit in text.runes) {
      // Combining Diacritical Marks (0300-036F)
      if (codeUnit >= 0x0300 && codeUnit <= 0x036F) return true;
      // Combining Diacritical Marks Extended (1AB0-1AFF)
      if (codeUnit >= 0x1AB0 && codeUnit <= 0x1AFF) return true;
      // Combining Diacritical Marks Supplement (1DC0-1DFF)
      if (codeUnit >= 0x1DC0 && codeUnit <= 0x1DFF) return true;
      // Combining Diacritical Marks for Symbols (20D0-20FF)
      if (codeUnit >= 0x20D0 && codeUnit <= 0x20FF) return true;
      // Combining Half Marks (FE20-FE2F)
      if (codeUnit >= 0xFE20 && codeUnit <= 0xFE2F) return true;
    }
    return false;
  }

  /// Applies NFC normalization to the text.
  ///
  /// This uses a lookup-based approach for common combining sequences,
  /// falling back to the original text for unsupported combinations.
  String _applyNFCNormalization(String text) {
    final buffer = StringBuffer();
    final runes = text.runes.toList();
    var i = 0;

    while (i < runes.length) {
      final codePoint = runes[i];

      // Check if next character is a combining mark
      if (i + 1 < runes.length && _isNfcCombiningMark(runes[i + 1])) {
        final combined = _composeCharacter(codePoint, runes[i + 1]);
        if (combined != null) {
          buffer.writeCharCode(combined);
          i += 2;
          continue;
        }
      }

      buffer.writeCharCode(codePoint);
      i++;
    }

    return buffer.toString();
  }

  /// Checks if a code point is a combining mark for NFC normalization.
  /// Named differently to avoid conflict with existing method in text measurement.
  bool _isNfcCombiningMark(int codePoint) {
    // Combining Diacritical Marks (0300-036F)
    if (codePoint >= 0x0300 && codePoint <= 0x036F) return true;
    // Combining Diacritical Marks Extended (1AB0-1AFF)
    if (codePoint >= 0x1AB0 && codePoint <= 0x1AFF) return true;
    // Combining Diacritical Marks Supplement (1DC0-1DFF)
    if (codePoint >= 0x1DC0 && codePoint <= 0x1DFF) return true;
    // Combining Diacritical Marks for Symbols (20D0-20FF)
    if (codePoint >= 0x20D0 && codePoint <= 0x20FF) return true;
    // Combining Half Marks (FE20-FE2F)
    if (codePoint >= 0xFE20 && codePoint <= 0xFE2F) return true;
    return false;
  }

  /// Composes a base character with a combining mark into a single character.
  /// Returns null if the combination is not in the lookup table.
  int? _composeCharacter(int base, int combiningMark) {
    // Common Latin letter + combining acute accent (U+0301)
    if (combiningMark == 0x0301) {
      return _composeWithAcute(base);
    }
    // Combining grave accent (U+0300)
    if (combiningMark == 0x0300) {
      return _composeWithGrave(base);
    }
    // Combining circumflex accent (U+0302)
    if (combiningMark == 0x0302) {
      return _composeWithCircumflex(base);
    }
    // Combining tilde (U+0303)
    if (combiningMark == 0x0303) {
      return _composeWithTilde(base);
    }
    // Combining diaeresis (U+0308)
    if (combiningMark == 0x0308) {
      return _composeWithDiaeresis(base);
    }
    // Combining cedilla (U+0327)
    if (combiningMark == 0x0327) {
      return _composeWithCedilla(base);
    }
    return null;
  }

  int? _composeWithAcute(int base) {
    switch (base) {
      case 0x0041: return 0x00C1; // A -> Á
      case 0x0045: return 0x00C9; // E -> É
      case 0x0049: return 0x00CD; // I -> Í
      case 0x004F: return 0x00D3; // O -> Ó
      case 0x0055: return 0x00DA; // U -> Ú
      case 0x0059: return 0x00DD; // Y -> Ý
      case 0x0061: return 0x00E1; // a -> á
      case 0x0065: return 0x00E9; // e -> é
      case 0x0069: return 0x00ED; // i -> í
      case 0x006F: return 0x00F3; // o -> ó
      case 0x0075: return 0x00FA; // u -> ú
      case 0x0079: return 0x00FD; // y -> ý
      case 0x0043: return 0x0106; // C -> Ć
      case 0x0063: return 0x0107; // c -> ć
      case 0x004E: return 0x0143; // N -> Ń
      case 0x006E: return 0x0144; // n -> ń
      case 0x0053: return 0x015A; // S -> Ś
      case 0x0073: return 0x015B; // s -> ś
      case 0x005A: return 0x0179; // Z -> Ź
      case 0x007A: return 0x017A; // z -> ź
      default: return null;
    }
  }

  int? _composeWithGrave(int base) {
    switch (base) {
      case 0x0041: return 0x00C0; // A -> À
      case 0x0045: return 0x00C8; // E -> È
      case 0x0049: return 0x00CC; // I -> Ì
      case 0x004F: return 0x00D2; // O -> Ò
      case 0x0055: return 0x00D9; // U -> Ù
      case 0x0061: return 0x00E0; // a -> à
      case 0x0065: return 0x00E8; // e -> è
      case 0x0069: return 0x00EC; // i -> ì
      case 0x006F: return 0x00F2; // o -> ò
      case 0x0075: return 0x00F9; // u -> ù
      default: return null;
    }
  }

  int? _composeWithCircumflex(int base) {
    switch (base) {
      case 0x0041: return 0x00C2; // A -> Â
      case 0x0045: return 0x00CA; // E -> Ê
      case 0x0049: return 0x00CE; // I -> Î
      case 0x004F: return 0x00D4; // O -> Ô
      case 0x0055: return 0x00DB; // U -> Û
      case 0x0061: return 0x00E2; // a -> â
      case 0x0065: return 0x00EA; // e -> ê
      case 0x0069: return 0x00EE; // i -> î
      case 0x006F: return 0x00F4; // o -> ô
      case 0x0075: return 0x00FB; // u -> û
      default: return null;
    }
  }

  int? _composeWithTilde(int base) {
    switch (base) {
      case 0x0041: return 0x00C3; // A -> Ã
      case 0x004E: return 0x00D1; // N -> Ñ
      case 0x004F: return 0x00D5; // O -> Õ
      case 0x0061: return 0x00E3; // a -> ã
      case 0x006E: return 0x00F1; // n -> ñ
      case 0x006F: return 0x00F5; // o -> õ
      default: return null;
    }
  }

  int? _composeWithDiaeresis(int base) {
    switch (base) {
      case 0x0041: return 0x00C4; // A -> Ä
      case 0x0045: return 0x00CB; // E -> Ë
      case 0x0049: return 0x00CF; // I -> Ï
      case 0x004F: return 0x00D6; // O -> Ö
      case 0x0055: return 0x00DC; // U -> Ü
      case 0x0059: return 0x0178; // Y -> Ÿ
      case 0x0061: return 0x00E4; // a -> ä
      case 0x0065: return 0x00EB; // e -> ë
      case 0x0069: return 0x00EF; // i -> ï
      case 0x006F: return 0x00F6; // o -> ö
      case 0x0075: return 0x00FC; // u -> ü
      case 0x0079: return 0x00FF; // y -> ÿ
      default: return null;
    }
  }

  int? _composeWithCedilla(int base) {
    switch (base) {
      case 0x0043: return 0x00C7; // C -> Ç
      case 0x0063: return 0x00E7; // c -> ç
      case 0x0053: return 0x015E; // S -> Ş
      case 0x0073: return 0x015F; // s -> ş
      default: return null;
    }
  }

  /// Detects the primary script type of the given text.
  ///
  /// Examines the first strong directional character to determine
  /// the script type, which affects text direction and shaping hints.
  _ScriptType _detectScriptType(String text) {
    for (final codeUnit in text.runes) {
      final script = _getCodePointScript(codeUnit);
      if (script != _ScriptType.other) {
        return script;
      }
    }
    return _ScriptType.latin;
  }

  /// Returns the script type for a given code point.
  _ScriptType _getCodePointScript(int codePoint) {
    // Arabic script ranges
    if ((codePoint >= 0x0600 && codePoint <= 0x06FF) || // Arabic
        (codePoint >= 0x0750 && codePoint <= 0x077F) || // Arabic Supplement
        (codePoint >= 0x08A0 && codePoint <= 0x08FF) || // Arabic Extended-A
        (codePoint >= 0xFB50 && codePoint <= 0xFDFF) || // Arabic Presentation Forms-A
        (codePoint >= 0xFE70 && codePoint <= 0xFEFF)) { // Arabic Presentation Forms-B
      return _ScriptType.arabic;
    }

    // Hebrew script range
    if (codePoint >= 0x0590 && codePoint <= 0x05FF) {
      return _ScriptType.hebrew;
    }

    // Thai script range
    if (codePoint >= 0x0E00 && codePoint <= 0x0E7F) {
      return _ScriptType.thai;
    }

    // Devanagari script range
    if (codePoint >= 0x0900 && codePoint <= 0x097F) {
      return _ScriptType.devanagari;
    }

    // Bengali script range
    if (codePoint >= 0x0980 && codePoint <= 0x09FF) {
      return _ScriptType.bengali;
    }

    // Tamil script range
    if (codePoint >= 0x0B80 && codePoint <= 0x0BFF) {
      return _ScriptType.tamil;
    }

    // CJK ranges
    if ((codePoint >= 0x4E00 && codePoint <= 0x9FFF) || // CJK Unified Ideographs
        (codePoint >= 0x3400 && codePoint <= 0x4DBF) || // CJK Extension A
        (codePoint >= 0x20000 && codePoint <= 0x2A6DF) || // CJK Extension B
        (codePoint >= 0x3040 && codePoint <= 0x309F) || // Hiragana
        (codePoint >= 0x30A0 && codePoint <= 0x30FF) || // Katakana
        (codePoint >= 0xAC00 && codePoint <= 0xD7AF)) { // Hangul Syllables
      return _ScriptType.cjk;
    }

    // Latin, Greek, Cyrillic (LTR scripts)
    if ((codePoint >= 0x0041 && codePoint <= 0x005A) || // A-Z
        (codePoint >= 0x0061 && codePoint <= 0x007A) || // a-z
        (codePoint >= 0x00C0 && codePoint <= 0x024F) || // Latin Extended
        (codePoint >= 0x0370 && codePoint <= 0x03FF) || // Greek
        (codePoint >= 0x0400 && codePoint <= 0x04FF)) { // Cyrillic
      return _ScriptType.latin;
    }

    return _ScriptType.other;
  }

  /// Returns the appropriate text direction for the detected script.
  ui.TextDirection _getScriptDirection(_ScriptType script) {
    switch (script) {
      case _ScriptType.arabic:
      case _ScriptType.hebrew:
        return ui.TextDirection.rtl;
      default:
        return ui.TextDirection.ltr;
    }
  }

  /// Checks if the script requires complex text shaping.
  ///
  /// Complex scripts have features like:
  /// - Contextual shaping (Arabic)
  /// - Ligatures and conjuncts (Devanagari, Bengali, Tamil)
  /// - Reordering (Thai)
  bool _isComplexScript(_ScriptType script) {
    switch (script) {
      case _ScriptType.arabic:
      case _ScriptType.thai:
      case _ScriptType.devanagari:
      case _ScriptType.bengali:
      case _ScriptType.tamil:
        return true;
      default:
        return false;
    }
  }
}
