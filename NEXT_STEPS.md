# Next Steps

**Last Updated:** March 28, 2026

**Current Status:** ~82% Blink SVG parity | ~95% Filter parity | ~95% SMIL parity | 3,563 tests passing | 0 analyzer warnings

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen registry:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Active Feature Items (P0 Priorities)

1. **CSS/SMIL edge-case parity** - Complex shorthand resolution, unit handling, timing precision
2. **External content edge cases** - Advanced image transformations, nested foreignObject (60% → 75%)
3. **Code modularization** - Splitting large files for dev velocity

## Immediate (Execution Order)

1. Improve CSS/SMIL edge-case parity (timing precision, shorthand resolution).
2. Expand external content parity (advanced image transforms, nested foreignObject).
3. Continue modular refactor of remaining large files for dev velocity with API-stability and full regression checks.
   Priority targets: `svg_filters_primitives.dart`, `animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`, `animated_svg_picture_utils.dart`.
4. Add targeted regression fixtures for CSS/SMIL edge cases (timing/transform shorthand corner cases).

## Completed P0 Items (Closed)

- ~~**Advanced Typography**~~ - Text & Typography reached ~99% Blink parity.
- ~~**Advanced Filter Graph**~~ - All 17/17 FE primitives implemented with full input chain semantics (~95% filter parity).
- ~~**Advanced Clipping**~~ - clipPathUnits, nested clip-paths, clip-rule, complex compositions, hit-testing.
- ~~**Advanced Masking**~~ - maskUnits, maskContentUnits, luminance/alpha modes, layer compositing, hit-testing.
- ~~**use/symbol Inheritance**~~ - CSS cascade through shadow boundary, style inheritance, nested transforms, hit-testing.
- ~~**Light Sources**~~ - feDistantLight, fePointLight, feSpotLight with per-pixel lighting math.
- ~~**Component Transfer**~~ - All 5 function types (identity, table, discrete, linear, gamma).
- ~~**Advanced animateMotion**~~ - SMIL 88% → 95% (to-only/by-only/from-only modes, keyTimes→keyPoints implicit generation, discrete calcMode + keyPoints, closed path detection, zero-length segment handling, 60 tests).

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
