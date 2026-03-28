# Next Steps

**Last Updated:** March 28, 2026

**Current Status:** ~89-90% Blink SVG parity | ~97% Filter parity | ~97% SMIL parity | 4,145 tests passing | 0 analyzer warnings

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen registry:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Active Feature Items (P0 Priorities)

1. **Remaining CSS edge cases** - Complex selectors, advanced pseudo-classes (`:nth-child`, `:nth-of-type`)
2. **Performance optimization** - Render benchmarking, cache tuning, memory profiling
3. **Golden test coverage expansion** - Additional regression fixtures for edge cases
4. **Code modularization** - Remaining large files (`animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`)

## Immediate (Execution Order)

1. Reach 95%+ parity: implement remaining CSS selectors (`:nth-child`, `:nth-of-type`, `:nth-last-child`).
2. Performance optimization: add render benchmarks, profile memory usage, tune caches.
3. Expand golden test coverage for new edge cases discovered.
4. Continue modular refactor of remaining large files for dev velocity with API-stability and full regression checks.
   Priority targets: `animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`, `animated_svg_picture_utils.dart`.
5. Documentation improvements: API usage guides, example updates.

## Completed P0 Items (Closed)

- ~~**Edge Case Sprint (March 2026)**~~ - CSS shorthand resolution, unit handling precision, SMIL timing precision, advanced image transformations, filter primitive edge cases, hit-testing refinements (~206 new tests, parity ~82% → ~89-90%).
- ~~**Advanced Typography**~~ - Text & Typography reached ~99% Blink parity.
- ~~**Advanced Filter Graph**~~ - All 17/17 FE primitives implemented with full input chain semantics (~97% filter parity).
- ~~**Advanced Clipping**~~ - clipPathUnits, nested clip-paths, clip-rule, complex compositions, hit-testing.
- ~~**Advanced Masking**~~ - maskUnits, maskContentUnits, luminance/alpha modes, layer compositing, hit-testing.
- ~~**use/symbol Inheritance**~~ - CSS cascade through shadow boundary, style inheritance, nested transforms, hit-testing.
- ~~**Light Sources**~~ - feDistantLight, fePointLight, feSpotLight with per-pixel lighting math.
- ~~**Component Transfer**~~ - All 5 function types (identity, table, discrete, linear, gamma).
- ~~**Advanced animateMotion**~~ - SMIL ~97% (to-only/by-only/from-only modes, keyTimes→keyPoints implicit generation, discrete calcMode + keyPoints, closed path detection, zero-length segment handling, timing precision).

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
