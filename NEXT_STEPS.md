# Next Steps

**Last Updated:** March 30, 2026

**Current Status:** ~94-95% Blink SVG parity | ~99% Filter parity | ~97% SMIL parity | 4,403 tests passing | 0 analyzer errors

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen registry:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Active Feature Items (P0 Priorities)

1. **Wire remaining 12 edge case methods** - Methods requiring significant refactoring:
   - `_applyNestedMaskWithIntersection`
   - `_generateMaskCacheKey`
   - ForeignObject helpers (`_computeForeignObjectNestedSvgTransform`, `_parsePreserveAspectRatioForNested`)
   - Text layout helpers (`_computeTextElementAccumulatedTransform`, `_transformPointForText`, `_computeTextLengthDistribution`)
   - Bidi helpers (`_buildBidiContext`, `_resolveEffectiveBidiDirection`)
   - Hit test utilities (`_isZeroOpacity`, `_isHitTestExcluded`)
   - CSS shorthand (`_isShorthandProperty`)

## P1 - Performance Optimization

1. **Profile critical render paths** - Identify bottlenecks in filter chains, text rendering, animation loops
2. **Reduce memory allocations** - Optimize object creation in hot paths
3. **Cache optimization** - Review cache hit rates and eviction policies

## P2 - Advanced Edge Cases

1. **Advanced text positioning** - Unicode normalization, complex script shaping
2. **Advanced use/symbol CSS cascade** - Further edge case refinement
3. **CSS selector edge case refinement** - Advanced structural pseudo-class combinations

## Immediate (Execution Order)

1. Wire remaining 12 edge case methods into active render pipeline callsites.
2. Profile and optimize critical render paths for performance.
3. Address advanced text positioning edge cases (Unicode normalization, complex script shaping).
4. Refine use/symbol CSS cascade for remaining edge cases.

## Completed P0 Items (Closed)

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
