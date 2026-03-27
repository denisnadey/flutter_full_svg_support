# Next Steps

**Last Updated:** March 26, 2026

**Current Status:** ~74% Blink SVG parity | 3099 tests passing | 0 analyzer warnings

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen registry:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Active Feature Items (7 P0 Priorities)

1. **Light Sources** - Advanced feSpecularLighting/feDiffuseLighting light source positioning and attenuation
2. **Component Transfer** - Extended feComponentTransfer channel functions (table, discrete, linear, gamma)
3. **Filter Input-Graph** - Advanced non-source/background input chain semantics for complex filter pipelines
4. **use/symbol Inheritance** - Style and attribute inheritance edge cases in nested use/symbol references
5. **Advanced Clipping** - Complex clip-path compositions, clipPathUnits, nested clip-paths
6. **Advanced Masking** - Luminance masks, alpha channel handling, maskUnits/maskContentUnits
7. **Advanced Typography** - Remaining edge cases: complex ligatures, hanging-punctuation, baseline alignment in nested contexts (~90% complete)

## Immediate (Execution Order)

1. Expand advanced filter graph semantics (`feDropShadow`, `feMerge`/`feMergeNode`, non-source/background input parity).
2. Close remaining text edge cases (complex ligatures, hanging-punctuation precision, baseline alignment in nested contexts).
3. Expand advanced hit-testing semantics (`clipPath`/`mask`/`use` and text geometry edge cases).
4. Improve advanced `<use>`/`<symbol>` inheritance semantics.
5. Add targeted regression fixtures for CSS/SMIL edge cases (timing/transform shorthand corner cases).
6. Continue modular refactor of remaining large files (for AI/dev velocity) with API-stability and full regression checks after each split.
   Current priority targets: `svg_filters_primitives.dart`, `animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`.

## Validation After Each Step

```bash
.fvm/versions/3.32.0-1.0.pre/bin/dart analyze lib/ test/
.fvm/versions/3.32.0-1.0.pre/bin/flutter test
```

## Definition of Progress

A task is complete only when:
- behavior is covered by focused tests,
- example/playground demonstrates the feature if UI-visible,
- `CURRENT_STATUS.md` is updated if factual state changed,
- `docs/RESOLVED_ISSUES.md` is updated for closed bug classes.
