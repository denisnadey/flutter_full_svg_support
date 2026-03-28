# Next Steps

**Last Updated:** March 29, 2026

**Current Status:** ~93-94% Blink SVG parity | ~99% Filter parity | ~97% SMIL parity | 4,330+ tests passing | 0 analyzer warnings

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen registry:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Active Feature Items (P0 Priorities)

1. **Integrate edge case methods into render pipeline** - Wire up new edge case utility methods into active render path callsites
2. **Address pre-existing golden test failures** - Fix known failing golden tests

## P1 - Code Modularization

1. **Remaining large files** - `text_layout` (785 lines), `text_style_positioning` (679 lines), `clip_mask_advanced` (715+ lines)
2. Full regression checks after each split, API stability preserved

## P2 - Quality & Coverage

1. **CSS selector edge case refinement** - Advanced structural pseudo-class combinations
2. **Golden test coverage expansion** - Additional regression fixtures for edge cases

## Immediate (Execution Order)

1. Integrate edge case utility methods into active render pipeline callsites.
2. Address pre-existing golden test failures.
3. Expand golden test coverage for new edge cases.
4. Continue modular refactor of remaining large files with API-stability and full regression checks.
   Priority targets: `text_layout` (785 lines), `text_style_positioning` (679 lines), `clip_mask_advanced` (715+ lines).

## Completed P0 Items (Closed)

- ~~**Code Modularization Sprint (March 2026)**~~ - `animated_svg_painter.dart` split from 941→190 lines (3 part files), `animated_svg_picture.dart` split from 627→194 lines (5 part files). All 4,310 tests pass.
- ~~**Performance Benchmarking Suite (March 2026)**~~ - 5 new benchmark files (filter_chain, text_render, animation_render, combined_worst_case, memory), CacheStats class for profiling, benchmark runner sections 6-10.
- ~~**Text/Mask/Image Edge Cases (March 2026)**~~ - 21 new tests covering deeply nested tspan transforms, bidi in complex hierarchies, textLength distribution, radial gradient luminance masks, filter chains on mask content, mask-to-mask intersection, image error fallback, nested SVG in foreignObject.
- ~~**Edge Case Sprint (March 2026)**~~ - CSS shorthand resolution, unit handling precision, SMIL timing precision, advanced image transformations, filter primitive edge cases, hit-testing refinements (~206 new tests, parity ~82% → ~89-90%).
- ~~**Advanced Typography**~~ - Text & Typography reached ~99% Blink parity.
- ~~**Advanced Filter Graph**~~ - All 17/17 FE primitives implemented with full input chain semantics (~97% filter parity).
- ~~**Advanced Clipping**~~ - clipPathUnits, nested clip-paths, clip-rule, complex compositions, hit-testing.
- ~~**Advanced Masking**~~ - maskUnits, maskContentUnits, luminance/alpha modes, layer compositing, hit-testing.
- ~~**use/symbol Inheritance**~~ - CSS cascade through shadow boundary, style inheritance, nested transforms, hit-testing.
- ~~**Light Sources**~~ - feDistantLight, fePointLight, feSpotLight with per-pixel lighting math.
- ~~**Component Transfer**~~ - All 5 function types (identity, table, discrete, linear, gamma).
- ~~**Advanced animateMotion**~~ - SMIL ~95% → ~97% (to-only/by-only/from-only modes, keyTimes→keyPoints implicit generation, discrete calcMode + keyPoints, closed path detection, zero-length segment handling, timing precision).
- ~~**Filter & Clipping Edge Cases (March 2026)**~~ - feMorphology edge modes (7 tests), feTurbulence seamless stitchTiles (12 tests), advanced filter input-graph semantics, advanced use/symbol inheritance (19 tests), advanced clipping semantics (67 tests). ~105+ new tests, parity ~89-90% → ~91-92%.

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
