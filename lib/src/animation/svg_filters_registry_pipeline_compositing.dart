part of 'svg_filters.dart';

extension SvgFiltersPipelineCompositingExtension on SvgFilters {
  List<SvgFilterPaintPass> _resolveBlendOutput({
    required SvgBlendFilter blend,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final inputRef = blend.input?.trim();
    final input = _resolveInputPasses(
      requestedInput: inputRef,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (inputRef != null && inputRef.isNotEmpty && input.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }

    final blendedTop = input
        .map((pass) => pass.copyWith(blendMode: blend.mode))
        .toList(growable: false);
    final input2Ref = blend.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);
    if (input2Ref == null || input2Ref.isEmpty || input2IsNone) {
      return blendedTop;
    }

    final input2 = _resolveInputPasses(
      requestedInput: input2Ref,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (input2.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }
    return <SvgFilterPaintPass>[...input2, ...blendedTop];
  }

  List<SvgFilterPaintPass> _resolveCompositeOutput({
    required SvgCompositeFilter composite,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final inputRef = composite.input?.trim();
    final input = _resolveInputPasses(
      requestedInput: inputRef,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (inputRef != null && inputRef.isNotEmpty && input.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }

    if (composite.mode == null) {
      return _resolveArithmeticCompositePasses(
        composite: composite,
        input: input,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
      );
    }

    final compositedTop = input
        .map((pass) => pass.copyWith(blendMode: composite.mode))
        .toList(growable: false);
    final input2Ref = composite.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);
    if (input2Ref == null || input2Ref.isEmpty || input2IsNone) {
      return compositedTop;
    }

    final input2 = _resolveInputPasses(
      requestedInput: input2Ref,
      previous: previous,
      namedResults: namedResults,
      sourceGraphic: sourceGraphic,
      sourceAlpha: sourceAlpha,
    );
    if (input2.isEmpty) {
      return const <SvgFilterPaintPass>[];
    }
    return <SvgFilterPaintPass>[...input2, ...compositedTop];
  }

  List<SvgFilterPaintPass> _resolveMergeOutput({
    required SvgMergeFilter merge,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final merged = <SvgFilterPaintPass>[];
    if (merge.nodeInputs.isEmpty) {
      merged.addAll(previous);
      return merged.isEmpty ? previous : merged;
    }

    for (final nodeInput in merge.nodeInputs) {
      merged.addAll(
        _resolveInputPasses(
          requestedInput: nodeInput,
          previous: previous,
          namedResults: namedResults,
          sourceGraphic: sourceGraphic,
          sourceAlpha: sourceAlpha,
          // Explicit unresolved merge-node inputs are treated as empty inputs.
          // Implicit node input (missing `in`) still resolves via previous-chain
          // semantics.
        ),
      );
    }
    return merged;
  }

  List<SvgFilterPaintPass> _resolveArithmeticCompositePasses({
    required SvgCompositeFilter composite,
    required List<SvgFilterPaintPass> input,
    required List<SvgFilterPaintPass> previous,
    required Map<String, List<SvgFilterPaintPass>> namedResults,
    required List<SvgFilterPaintPass> sourceGraphic,
    required List<SvgFilterPaintPass> sourceAlpha,
  }) {
    final k1 = composite.k1;
    final k2 = composite.k2;
    final k3 = composite.k3;
    final k4 = composite.k4;

    final k1Zero = _isApproximately(k1, 0.0);
    final k2Zero = _isApproximately(k2, 0.0);
    final k3Zero = _isApproximately(k3, 0.0);
    final k4Zero = _isApproximately(k4, 0.0);
    final k2One = _isApproximately(k2, 1.0);
    final k3One = _isApproximately(k3, 1.0);

    // arithmetic with all-zero coefficients produces transparent black.
    if (k1Zero && k2Zero && k3Zero && k4Zero) {
      return const <SvgFilterPaintPass>[];
    }

    // arithmetic(k2=1) degenerates to input image.
    if (k1Zero && k3Zero && k4Zero && k2One) {
      return input;
    }

    final input2Ref = composite.input2?.trim();
    final input2IsNone = _isNoneInputReference(input2Ref);

    List<SvgFilterPaintPass> resolveInput2() {
      if (input2IsNone) {
        return const <SvgFilterPaintPass>[];
      }
      return _resolveInputPasses(
        requestedInput: input2Ref,
        previous: previous,
        namedResults: namedResults,
        sourceGraphic: sourceGraphic,
        sourceAlpha: sourceAlpha,
      );
    }

    // arithmetic(k3=1) degenerates to in2.
    if (k1Zero && k2Zero && k4Zero && k3One) {
      if (input2Ref == null || input2Ref.isEmpty) {
        return input;
      }
      final input2 = resolveInput2();
      return input2.isEmpty ? const <SvgFilterPaintPass>[] : input2;
    }

    // arithmetic(k2=1,k3=1) approximates additive composition of in and in2.
    if (k1Zero && k4Zero && k2One && k3One) {
      if (input2Ref == null || input2Ref.isEmpty) {
        return input;
      }
      final input2 = resolveInput2();
      if (input2.isEmpty && !input2IsNone) {
        return const <SvgFilterPaintPass>[];
      }
      final additiveTop = input
          .map((pass) => pass.copyWith(blendMode: ui.BlendMode.plus))
          .toList(growable: false);
      return <SvgFilterPaintPass>[...input2, ...additiveTop];
    }

    return input;
  }

  bool _isNoneInputReference(String? inputRef) {
    if (inputRef == null) {
      return false;
    }
    return inputRef.trim().toLowerCase() == 'none';
  }

  bool _isApproximately(
    double value,
    double expected, [
    double epsilon = 1e-6,
  ]) {
    return (value - expected).abs() <= epsilon;
  }
}
