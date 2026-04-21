# Next Steps

**Last Updated:** April 21, 2026

**Current Status:** historical ~97%+ parity baseline; active W3C functional recovery with first-40 green, `filters-light-03-f` and `filters-specular-01-f` closed, remaining functional debt centered on legacy font fixtures.

Authoritative status is maintained in:

- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen registry:

- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

Detailed Blink gap matrix:

- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

Active W3C execution plan (Chromium-driven, diff-measured thresholds):

- `/Users/denisnadey/apps/flutter_full_svg_support/docs/W3C_GAP_CLOSURE_PLAN.md`

Release gate checklist:

- `/Users/denisnadey/apps/flutter_full_svg_support/RELEASE_CHECKLIST.md`

## Active Feature Items (P0 Priorities)

W3C functional closure is active. Treat legacy “all complete” notes below as historical records.

1. Functional closure of remaining first-40 `fonts-*` fixtures.
2. Stepwise rollback of case-scoped normalization overrides after each functional fix.
3. Keep W3C trace-driven forensic workflow for stubborn mismatches.

## P1 - Performance Optimization

_Initial optimization pass completed March 31, 2026. Future optimizations tracked as P2._

1. **Additional profiling** - Ongoing identification of bottlenecks if needed
2. **Memory allocation monitoring** - Monitor object creation in hot paths

## P2 - Advanced Edge Cases

_All P2 edge case items completed March 31, 2026. See Completed P0 Items below._

## P2/P3 - Remaining Work

1. Additional profiling - Ongoing identification of bottlenecks if needed
2. Memory allocation monitoring - Monitor object creation in hot paths
3. CSS selector edge case refinement - Advanced structural pseudo-class combinations

## Immediate (Execution Order)

1. Execute Wave A/B/C from `docs/W3C_GAP_CLOSURE_PLAN.md` to close highest-delta W3C failures first.
2. Continue rollback of case-scoped normalization overrides where renderer parity is now stable.
3. Then continue with profiling and memory optimization work.

## Completed P0 Items (Closed)

- ~~**Final CSS Compositing Properties Sprint (March 31, 2026)**~~ - Fixed all 10 analyzer warnings (dead code removal from clip/mask and bidi text), implemented `enable-background: new` (saveLayer + background context push/pop), `color-interpolation-filters` (CSS cascade + sRGB↔linearRGB pixel conversion with LUT), `isolation: isolate` (stacking context + implicit group blend mode isolation). 14 new tests, 4,896 tests passing, 0 warnings.
- ~~**Advanced Parity Sprint (March 31, 2026)**~~ - 8 tasks completed, ~548 new tests, parity ~95-96% → ~96-97%, 4,882 tests passing:
  - Unicode normalization and complex script text (NFC, Arabic/Thai/Devanagari/CJK detection, grapheme cluster hit-testing) - 25 tests
  - Advanced bi-directional text edge cases (BDO element, unicode-bidi interaction, mixed RTL/LTR reordering) - 18 tests
  - CSS cascade through use/symbol shadow boundary (selector matching, nested inheritance, transform stacking, event retargeting) - 20 tests
  - Use element in clip-path/mask (use resolution, symbol viewBox in mask, objectBoundingBox coordinates) - 19 tests
  - Filter input-graph advanced chains (multi-reference caching, FillPaint/StrokePaint sources, cycle prevention) - 23 tests
  - Filter primitive edge cases (feTurbulence tile stitching, feDisplacementMap bilinear interpolation, feComponentTransfer clamping) - 76 tests
  - Advanced clip/mask composition (cascading clip-paths, luminance mask formula, maskContentUnits transitions) - 16 tests
  - Blink-style regression test suite - 351 new regression tests
- ~~**Wire Edge Case Methods & Optimization Sprint (March 31, 2026)**~~ - Wired all 12 staged methods into active render pipeline (mask cache keys, nested mask intersection, foreignObject nested SVG transforms, text accumulated transforms, textLength distribution, bidi context/direction, hit test exclusion with pointer-events, CSS shorthand guard), added 93 new tests, reduced analyzer warnings from 13→1, performance optimizations (cache eviction policies, in-place matrix ops, regex reduction). All 4,496 tests pass, parity ~94-95% → ~95-96%.
- ~~**Render Pipeline & Golden Test Sprint (March 30, 2026)**~~ - Integrated edge case methods (data URI validation, mask animation tracking, gradient-aware luminance masking, alpha threshold hit testing), fixed all golden test failures (25 passing), expanded golden test coverage (19 new fixtures, 44 total), modularized 3 large files into 7 part files, verified filter light sources and input-graph semantics (32 new tests). All 4,403 tests pass.
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
