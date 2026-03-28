part of 'svg_filters.dart';

extension SvgFiltersPipelinePrimitiveEffectsExtension on SvgFilters {
  List<SvgFilterPaintPass> _resolveGaussianBlurOutput({
    required SvgGaussianBlurFilter blur,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: blur.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    final blurFilter = blur.apply();
    return input
        .map(
          (pass) => pass.copyWith(
            imageFilter: _composeImageFilter(blurFilter, pass.imageFilter),
          ),
        )
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolveMorphologyOutput({
    required SvgMorphologyFilter morphology,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: morphology.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );

    final clampedX = morphology.radiusX.clamp(0.0, 4096.0).toDouble();
    final clampedY = morphology.radiusY.clamp(0.0, 4096.0).toDouble();
    if (clampedX <= 0.0 && clampedY <= 0.0) {
      return input;
    }

    // For non-default edge modes, use specialized paint pass that
    // carries the morphology parameters for proper edge handling.
    if (morphology.edgeMode != SvgConvolveEdgeMode.duplicate) {
      return input
          .map(
            (pass) => SvgMorphologyPaintPass(
              imageFilter: pass.imageFilter,
              colorFilter: pass.colorFilter,
              blendMode: pass.blendMode,
              offset: pass.offset,
              paintFill: pass.paintFill,
              paintStroke: pass.paintStroke,
              morphologyFilter: morphology,
            ),
          )
          .toList(growable: false);
    }

    // Default edge mode (duplicate) - use Flutter's built-in erode/dilate
    final morphologyFilter = morphology.apply();
    if (morphologyFilter == null) {
      return input;
    }

    return input
        .map(
          (pass) => pass.copyWith(
            imageFilter: _composeImageFilter(
              morphologyFilter,
              pass.imageFilter,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolveDisplacementMapOutput({
    required SvgDisplacementMapFilter displacement,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: displacement.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );

    final zeroScale = displacement.scale.abs() <= 0.000001;
    final input2Ref = displacement.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);
    if (!zeroScale &&
        input2Ref != null &&
        input2Ref.isNotEmpty &&
        !input2IsNone) {
      final input2 = _resolvePrimitiveInput(
        requestedInput: input2Ref,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
      );
      // If explicit in2 cannot be resolved, this primitive produces no output
      // instead of inheriting previous output.
      return input2.isEmpty ? const <SvgFilterPaintPass>[] : input;
    }

    // scale=0 is identity displacement and does not require map input.
    return input;
  }

  List<SvgFilterPaintPass> _resolveImagePrimitiveOutput({
    required SvgFeImageFilter imagePrimitive,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final inputRef = imagePrimitive.input?.trim();
    if (inputRef != null && inputRef.isNotEmpty) {
      return _resolvePrimitiveInput(
        requestedInput: inputRef,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
      );
    }

    final href = (imagePrimitive.href ?? '').trim();
    if (href.isEmpty) {
      // No href specified - return previous or SourceGraphic as fallback.
      return previous.isEmpty
          ? <SvgFilterPaintPass>[...sourceGraphic]
          : previous;
    }

    // Per SVG spec, feImage with href starts a new primitive output
    // instead of inheriting previous chain state.
    //
    // If href references an SVG element (#id) or external image,
    // create a specialized paint pass that carries the feImage config.
    // The painter will use this to render the referenced content.
    //
    // For unresolvable references, return transparent black (empty list)
    // per SVG spec. The painter handles this by checking if the
    // referenced element/image exists.
    return <SvgFilterPaintPass>[
      SvgFeImagePaintPass(
        feImageFilter: imagePrimitive,
        // No source-derived filters for feImage - it's a new source.
        paintFill: true,
        paintStroke: true,
      ),
    ];
  }

  List<SvgFilterPaintPass> _resolveDiffuseLightingOutput({
    required SvgDiffuseLightingFilter lighting,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: lighting.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );

    // If no light source, pass through unchanged
    if (lighting.lightSource == null) {
      return input;
    }

    // Create specialized paint passes for per-pixel lighting computation
    return input
        .map(
          (pass) => SvgDiffuseLightingPaintPass(
            lightingFilter: lighting,
            imageFilter: pass.imageFilter,
            colorFilter: pass.colorFilter,
            blendMode: pass.blendMode,
            offset: pass.offset,
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
          ),
        )
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolveSpecularLightingOutput({
    required SvgSpecularLightingFilter lighting,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: lighting.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );

    // If no light source, pass through unchanged
    if (lighting.lightSource == null) {
      return input;
    }

    // Create specialized paint passes for per-pixel lighting computation
    return input
        .map(
          (pass) => SvgSpecularLightingPaintPass(
            lightingFilter: lighting,
            imageFilter: pass.imageFilter,
            colorFilter: pass.colorFilter,
            blendMode: pass.blendMode,
            offset: pass.offset,
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
          ),
        )
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolveConvolveMatrixOutput({
    required SvgConvolveMatrixFilter convolve,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: convolve.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );

    // Check if kernel is an identity kernel (no-op)
    final isIdentity = ConvolveMatrixProcessor.isIdentityKernel(
      kernel: convolve.kernelMatrix,
      orderX: convolve.orderX,
      orderY: convolve.orderY,
      targetX: convolve.targetX,
      targetY: convolve.targetY,
      divisor: convolve.divisor,
      bias: convolve.bias,
    );

    if (isIdentity) {
      // Identity kernel - pass through without convolution
      return input;
    }

    // Create convolution paint passes that wrap input passes
    return input
        .map(
          (pass) => SvgConvolveMatrixPaintPass(
            imageFilter: pass.imageFilter,
            colorFilter: pass.colorFilter,
            blendMode: pass.blendMode,
            offset: pass.offset,
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
            convolveFilter: convolve,
          ),
        )
        .toList(growable: false);
  }

  List<SvgFilterPaintPass> _resolveComponentTransferOutput({
    required SvgComponentTransferFilter transfer,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final input = _resolvePrimitiveInput(
      requestedInput: transfer.input,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );

    // If all channels are identity, pass through unchanged
    if (transfer.isIdentity) {
      return input;
    }

    // Try to use a color matrix for simple linear transforms
    final linearFilter = transfer.linearColorFilter();
    if (linearFilter != null) {
      return input
          .map((pass) => pass.copyWith(colorFilter: linearFilter))
          .toList(growable: false);
    }

    // For table, discrete, or gamma functions, create specialized paint passes
    return input
        .map(
          (pass) => SvgComponentTransferPaintPass(
            transferFilter: transfer,
            imageFilter: pass.imageFilter,
            colorFilter: pass.colorFilter,
            blendMode: pass.blendMode,
            offset: pass.offset,
            paintFill: pass.paintFill,
            paintStroke: pass.paintStroke,
          ),
        )
        .toList(growable: false);
  }

  /// Resolves feTurbulence output with fractal noise generation.
  ///
  /// feTurbulence generates procedural Perlin noise with the following properties:
  /// - baseFrequency: Controls the scale of the noise pattern
  /// - numOctaves: Number of noise layers summed together (fractal octaves)
  /// - seed: Random seed for deterministic noise generation
  /// - type: 'turbulence' (absolute value) or 'fractalNoise' (signed)
  /// - stitchTiles: Whether to create seamless tiling patterns
  ///
  /// Blink's implementation uses classic Perlin noise with fBm (fractional
  /// Brownian motion) for octave summation. Each octave adds finer detail
  /// at half the amplitude and double the frequency.
  List<SvgFilterPaintPass> _resolveTurbulenceOutput({
    required SvgTurbulenceFilter turbulence,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    // feTurbulence is a procedural generator - it doesn't use input.
    // Per SVG spec, it ignores the 'in' attribute and always generates
    // noise to fill the filter primitive subregion.
    //
    // Create a specialized paint pass that carries the turbulence parameters.
    // The painter will use these to generate the noise texture.
    return <SvgFilterPaintPass>[
      SvgTurbulencePaintPass(
        turbulenceFilter: turbulence,
        paintFill: true,
        paintStroke: true,
      ),
    ];
  }
}
