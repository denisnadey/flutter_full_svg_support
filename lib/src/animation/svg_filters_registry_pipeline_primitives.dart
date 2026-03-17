part of 'svg_filters.dart';

extension SvgFiltersPipelinePrimitiveResolverExtension on SvgFilters {
  List<SvgFilterPaintPass> _resolvePrimitiveOutput({
    required SvgFilter primitive,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    switch (primitive.type) {
      case SvgFilterType.gaussianBlur:
        return _resolveGaussianBlurOutput(
          blur: primitive as SvgGaussianBlurFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.morphology:
        return _resolveMorphologyOutput(
          morphology: primitive as SvgMorphologyFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.displacementMap:
        return _resolveDisplacementMapOutput(
          displacement: primitive as SvgDisplacementMapFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.image:
        return _resolveImagePrimitiveOutput(
          imagePrimitive: primitive as SvgFeImageFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.convolveMatrix:
        return _resolveConvolveMatrixOutput(
          convolve: primitive as SvgConvolveMatrixFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.turbulence:
        return _resolvePassthroughOutput(
          requestedInput: (primitive as SvgTurbulenceFilter).input,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.componentTransfer:
        return _resolvePassthroughOutput(
          requestedInput: (primitive as SvgComponentTransferFilter).input,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.diffuseLighting:
        return _resolveDiffuseLightingOutput(
          lighting: primitive as SvgDiffuseLightingFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.specularLighting:
        return _resolveSpecularLightingOutput(
          lighting: primitive as SvgSpecularLightingFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.offset:
        return _resolveOffsetOutput(
          offsetFilter: primitive as SvgOffsetFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.flood:
        return _resolveFloodOutput(primitive as SvgFloodFilter);

      case SvgFilterType.blend:
        return _resolveBlendOutput(
          blend: primitive as SvgBlendFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.composite:
        return _resolveCompositeOutput(
          composite: primitive as SvgCompositeFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.merge:
        return _resolveMergeOutput(
          merge: primitive as SvgMergeFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.tile:
        return _resolvePassthroughOutput(
          requestedInput: (primitive as SvgTileFilter).input,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.dropShadow:
        return _resolveDropShadowOutput(
          shadow: primitive as SvgDropShadowFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );

      case SvgFilterType.colorMatrix:
        return _resolveColorMatrixOutput(
          colorMatrix: primitive as SvgColorMatrixFilter,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
        );
    }
  }
}
