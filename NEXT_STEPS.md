# Next Steps

**Last Updated:** March 27, 2026

**Current Status:** ~75% Blink SVG parity | 3,413+ tests passing | 0 analyzer warnings

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen registry:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Active Feature Items (6 P0 Priorities)

1. **Advanced Filter Graph** - Non-source/background input chain semantics, 8 remaining FE primitives, advanced feDropShadow/feMerge composition
2. **Advanced Clipping** - Complex clip-path compositions, clipPathUnits, nested clip-paths
3. **Advanced Masking** - Luminance masks, alpha channel handling, maskUnits/maskContentUnits
4. **use/symbol Inheritance** - Style and attribute inheritance edge cases in nested use/symbol references
5. **Light Sources** - Advanced feSpecularLighting/feDiffuseLighting light source positioning and attenuation
6. **Component Transfer** - Extended feComponentTransfer channel functions (table, discrete, linear, gamma)

## Immediate (Execution Order)

1. Expand advanced filter graph semantics (`feDropShadow`, `feMerge`/`feMergeNode`, non-source/background input parity).
2. Expand advanced clipping/masking parity (complex compositions, luminance masks, alpha channels).
3. Expand advanced hit-testing semantics (`clipPath`/`mask`/`use` and text geometry edge cases).
4. Improve advanced `<use>`/`<symbol>` inheritance semantics.
5. Add targeted regression fixtures for CSS/SMIL edge cases (timing/transform shorthand corner cases).
6. Continue modular refactor of remaining large files (for AI/dev velocity) with API-stability and full regression checks after each split.
   Current priority targets: `svg_filters_primitives.dart`, `animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`.

## Completed P0 Items (Closed)

- ~~**Advanced Typography**~~ - Text & Typography reached ~99% Blink parity: hanging punctuation, deep baseline alignment, complex ligature shaping all implemented and tested.

## Validation After Each Step

```bash
.fvm/versions/3.38.1/bin/dart analyze lib/ test/
.fvm/versions/3.38.1/bin/flutter test
```

## Definition of Progress

A task is complete only when:
- behavior is covered by focused tests,
- example/playground demonstrates the feature if UI-visible,
- `CURRENT_STATUS.md` is updated if factual state changed,
- `docs/RESOLVED_ISSUES.md` is updated for closed bug classes.
