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

    if ((imagePrimitive.href ?? '').trim().isNotEmpty) {
      // Non-source primitive semantics: feImage with href starts a new
      // primitive output instead of inheriting previous chain state.
      // Baseline renderer uses SourceGraphic as placeholder source.
      return <SvgFilterPaintPass>[...sourceGraphic];
    }

    return previous.isEmpty ? <SvgFilterPaintPass>[...sourceGraphic] : previous;
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

    final colorFilter = lighting.colorFilter();
    if (colorFilter == null) {
      // No light source or zero intensity - pass through input
      return input;
    }

    return input
        .map((pass) => pass.copyWith(colorFilter: colorFilter))
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

    final colorFilter = lighting.colorFilter();
    if (colorFilter == null) {
      // No light source or zero intensity - pass through input
      return input;
    }

    return input
        .map((pass) => pass.copyWith(colorFilter: colorFilter))
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
}
