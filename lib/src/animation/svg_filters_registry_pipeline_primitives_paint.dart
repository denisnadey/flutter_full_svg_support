part of 'svg_filters.dart';

/// Specialized paint pass for FillPaint input source.
///
/// Per SVG Filter 1.1 spec, FillPaint generates an image filled with the
/// element's current fill paint. This enables filter effects like:
/// - Fill-aware color manipulation
/// - Outline effects based on fill color
/// - Paint server-aware filtering (gradients, patterns)
///
/// When the element has a solid fill, this creates a uniform color image.
/// When the element has a gradient or pattern fill, the paint's rendered
/// appearance is used.
class SvgFillPaintSourcePass extends SvgFilterPaintPass {
  const SvgFillPaintSourcePass({
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    this.fillColor,
  }) : super(paintFill: true, paintStroke: false);

  /// The solid fill color, if available.
  /// Null when fill is a gradient or pattern.
  final ui.Color? fillColor;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgFillPaintSourcePass(
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      fillColor: fillColor,
    );
  }
}

/// Specialized paint pass for StrokePaint input source.
///
/// Per SVG Filter 1.1 spec, StrokePaint generates an image filled with the
/// element's current stroke paint. This enables filter effects like:
/// - Stroke-aware color manipulation
/// - Stroke-based glow or shadow effects
/// - Paint server-aware stroke filtering
///
/// When the element has a solid stroke, this creates a uniform color image.
/// When the element has a gradient or pattern stroke, the paint's rendered
/// appearance is used.
class SvgStrokePaintSourcePass extends SvgFilterPaintPass {
  const SvgStrokePaintSourcePass({
    super.imageFilter,
    super.colorFilter,
    super.blendMode,
    super.offset,
    this.strokeColor,
  }) : super(paintFill: false, paintStroke: true);

  /// The solid stroke color, if available.
  /// Null when stroke is a gradient or pattern.
  final ui.Color? strokeColor;

  @override
  SvgFilterPaintPass copyWith({
    ui.ImageFilter? imageFilter,
    ui.ColorFilter? colorFilter,
    ui.BlendMode? blendMode,
    ui.Offset? offset,
    bool? paintFill,
    bool? paintStroke,
  }) {
    return SvgStrokePaintSourcePass(
      imageFilter: imageFilter ?? this.imageFilter,
      colorFilter: colorFilter ?? this.colorFilter,
      blendMode: blendMode ?? this.blendMode,
      offset: offset ?? this.offset,
      strokeColor: strokeColor,
    );
  }
}

extension SvgFiltersPipelinePrimitivePaintExtension on SvgFilters {
  List<SvgFilterPaintPass> _resolvePassthroughOutput({
    required String? requestedInput,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    return _resolvePrimitiveInput(
      requestedInput: requestedInput,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
  }

  List<SvgFilterPaintPass> _resolveOffsetOutput({
    required SvgOffsetFilter offsetFilter,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: offsetFilter.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    return input
        .map(
          (pass) => pass.copyWith(
            offset: pass.offset + ui.Offset(offsetFilter.dx, offsetFilter.dy),
          ),
        )
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolveFloodOutput(SvgFloodFilter flood) {
    return <SvgFilterPaintPass>[
      SvgSolidPaintSourcePass(
        paintColor: flood.effectiveColor,
        colorFilter: ui.ColorFilter.mode(flood.effectiveColor, ui.BlendMode.src),
      ),
    ];
  }

  /// Resolves feDropShadow output using Blink's multi-pass composition.
  ///
  /// feDropShadow is a convenience primitive that expands to the following
  /// filter primitive sub-graph per SVG Filter 1.1 spec and Blink's impl:
  /// 1. Extract alpha from input (SourceAlpha equivalent)
  /// 2. feGaussianBlur - blur the alpha with stdDeviation
  /// 3. feOffset - offset by dx/dy
  /// 4. feFlood - fill with shadow color (flood-color * flood-opacity)
  /// 5. feComposite in="flood" in2="blurredAlpha" operator="in" - cut flood to blur shape
  /// 6. feMerge - combine shadow with original input (shadow behind, input on top)
  ///
  /// Blink's multi-pass approach ensures:
  /// - Shadow shape comes from blurred alpha, not RGB
  /// - Flood color is multiplied by the blurred alpha mask
  /// - Result is properly composited behind the source
  ///
  /// Advanced input handling (per SVG spec):
  /// - Custom `in` attribute: The input can be any valid input reference
  ///   (SourceGraphic, SourceAlpha, named result, FillPaint, etc.)
  /// - When `in` references a named result from a previous primitive, the
  ///   shadow is applied to that result's content
  /// - Multiple feDropShadow in sequence: Each feDropShadow processes the
  ///   output of the previous (if `in` is omitted) or the specified input
  /// - `in="none"`: produces empty output (no shadow, no source)
  ///
  /// Composition order with explicit input chains:
  /// - Shadow passes come first (bottom layer)
  /// - Original input passes come last (top layer)
  /// - This ensures shadow renders behind the source content
  ///
  /// Chaining considerations:
  /// - If feDropShadow has a result name, downstream primitives can reference it
  /// - The result contains both shadow passes and source passes (merged)
  /// - When chained, subsequent primitives process all output passes
  /// - Sequential feDropShadow filters accumulate shadow layers
  ///
  /// Input validation and edge cases:
  /// - Empty/unresolved input: returns empty passes (transparent black)
  /// - stdDeviation=0: skips blur filter but still applies offset/color
  /// - flood-opacity=0: produces fully transparent shadow (still layered)
  /// - Multiple downstream references: each gets a copy of all passes
  /// - `in="none"`: produces empty output, no fallback to previous
  List<SvgFilterPaintPass> _resolveDropShadowOutput({
    required SvgDropShadowFilter shadow,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    // Check for explicit in="none" - produces empty output.
    final inputRef = shadow.input?.trim();
    if (inputRef != null && inputRef.toLowerCase() == 'none') {
      return const <SvgFilterPaintPass>[];
    }

    // Resolve the input (can be SourceGraphic, named result, or previous output).
    // Per SVG spec, feDropShadow can reference any valid input, not just
    // SourceGraphic. This enables applying shadow to filtered results.
    final input = _resolvePrimitiveInput(
      requestedInput: shadow.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );

    // HARDENING: If input is empty (e.g., unresolved reference or in="none"),
    // produce no shadow. This matches the SVG spec behavior where invalid/forward
    // references produce transparent black output.
    if (input.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }

    // Get the blur filter (stdDeviation-based gaussian blur).
    final blurFilter = shadow.apply();

    // Check for zero blur (optimization: skip blur composition).
    // HARDENING: Check both X and Y independently for asymmetric blur cases.
    final hasBlur = shadow.stdDeviationX > 0 || shadow.stdDeviationY > 0;

    // Blink's multi-pass composition approach:
    // Step 1: Extract alpha from input (implicit via srcIn blend)
    // Step 2: Apply blur to the alpha mask
    // Step 3: Apply offset
    // Step 4: Flood color with srcIn to cut flood to blurred alpha shape
    // Step 5: Merge shadow behind source

    final shadowColor = shadow.effectiveShadowColor;

    // Create shadow passes from input using Blink's multi-pass approach:
    // 1. blur(alpha) -> 2. offset -> 3. flood*alpha via srcIn
    //
    // For sequential feDropShadow filters, each shadow pass is created from
    // the input (which may already contain shadow+source from previous filter).
    final shadowPasses = input
        .map(
          (pass) => SvgDropShadowPaintPass(
            // Compose blur filter with any existing filter on the input pass.
            // This blurs the alpha channel shape for the shadow.
            imageFilter: hasBlur
                ? _composeImageFilter(blurFilter, pass.imageFilter)
                : pass.imageFilter,
            // Apply shadow color using srcIn to properly multiply flood color
            // with the blurred alpha mask (Blink's feComposite in="flood" in2="blur" operator="in").
            colorFilter: ui.ColorFilter.mode(shadowColor, ui.BlendMode.srcIn),
            // Shadow renders with srcOver to blend behind the input.
            blendMode: ui.BlendMode.srcOver,
            // Apply the offset (dx/dy) to position the shadow.
            offset: pass.offset + shadow.offset,
            // Preserve paint channel scope from input.
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
            // Store shadow parameters for potential advanced rendering.
            shadowFilter: shadow,
          ),
        )
        .toList(growable: false);

    // Merge shadow passes (first/bottom) with original input (last/top).
    // This matches the SVG spec behavior where the shadow appears behind.
    // The resulting list is: [shadow_pass_0, ..., shadow_pass_n, input_0, ..., input_n]
    //
    // For sequential feDropShadow:
    // - First feDropShadow: [shadow1, source]
    // - Second feDropShadow (implicit input from first): [shadow2_of_shadow1, shadow2_of_source, shadow1, source]
    // This creates the correct layering for multiple shadows.
    //
    // HARDENING: Return a new list to prevent any mutation issues when this
    // result is cached and referenced by multiple downstream primitives.
    return <SvgFilterPaintPass>[...shadowPasses, ...input];
  }

  List<SvgFilterPaintPass> _resolveColorMatrixOutput({
    required SvgColorMatrixFilter colorMatrix,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: colorMatrix.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    final colorFilter = colorMatrix.colorFilter();
    if (colorFilter == null) {
      return input;
    }
    return input
        .map((pass) => _appendColorFilterPass(pass, colorFilter))
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolvePrimitiveInput({
    required String? requestedInput,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    return _resolveInputPasses(
      requestedInput: requestedInput,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
  }

  /// Creates FillPaint source passes for use as filter input.
  ///
  /// Per SVG Filter 1.1 spec, FillPaint uses the element's current fill paint
  /// to create the input image. When fill is a solid color, this generates
  /// an image filled with that color. For gradients/patterns, the paint's
  /// rendered appearance is used.
  ///
  /// This method creates specialized SvgFillPaintSourcePass instances that:
  /// - Carry the paintFill=true flag for proper rendering
  /// - Include the fill color when available for optimization
  /// - Support downstream filter processing (blur, offset, etc.)
  static List<SvgFilterPaintPass> createFillPaintSourcePasses({
    ui.Color? fillColor,
  }) {
    if (fillColor != null) {
      // Solid fill: create a pass with the color filter to produce filled image.
      return <SvgFilterPaintPass>[
        SvgFillPaintSourcePass(
          fillColor: fillColor,
          colorFilter: ui.ColorFilter.mode(fillColor, ui.BlendMode.srcIn),
        ),
      ];
    }
    // No specific color: use identity pass with paintFill flag.
    return const <SvgFilterPaintPass>[SvgFillPaintSourcePass()];
  }

  /// Creates StrokePaint source passes for use as filter input.
  ///
  /// Per SVG Filter 1.1 spec, StrokePaint uses the element's current stroke
  /// paint to create the input image. When stroke is a solid color, this
  /// generates an image filled with that color. For gradients/patterns, the
  /// paint's rendered appearance is used.
  ///
  /// This method creates specialized SvgStrokePaintSourcePass instances that:
  /// - Carry the paintStroke=true flag for proper rendering
  /// - Include the stroke color when available for optimization
  /// - Support downstream filter processing (blur, offset, etc.)
  static List<SvgFilterPaintPass> createStrokePaintSourcePasses({
    ui.Color? strokeColor,
  }) {
    if (strokeColor != null) {
      // Solid stroke: create a pass with the color filter to produce filled image.
      return <SvgFilterPaintPass>[
        SvgStrokePaintSourcePass(
          strokeColor: strokeColor,
          colorFilter: ui.ColorFilter.mode(strokeColor, ui.BlendMode.srcIn),
        ),
      ];
    }
    // No specific color: use identity pass with paintStroke flag.
    return const <SvgFilterPaintPass>[SvgStrokePaintSourcePass()];
  }
}
