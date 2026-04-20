# TODO - Animation Work Queue

**Last Updated:** April 21, 2026  
**Status Source:** `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`  
**Closed Issues Registry:** `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

**Current Status:** ~97%+ historical parity baseline; active W3C recovery with first-40 green, lighting/specular closure landed, and remaining open functional gaps concentrated in legacy font fixtures.

This file tracks actionable implementation tasks.
For factual project status, use `CURRENT_STATUS.md` only.

## Current Sprint (P0 - Active)

**W3C functional parity closure (April 2026)**

- [x] Close `filters-light-03-f` functionally (renderer behavior) and reduce temporary compare inflation.
- [x] Close `filters-specular-01-f` functionally (renderer behavior) and reduce temporary compare inflation.
- [ ] Close first-40 legacy `fonts-*` functional mismatches (not by global threshold tuning).
- [ ] Reduce/rollback case-scoped compare overrides in `test/w3c/w3c_render_utils.dart` as each fixture becomes functionally correct.
- [ ] Keep `W3C_TRACE` forensic workflow as mandatory diagnostics for stubborn fixtures.

Next sprint candidates (after functional closure):
- [ ] Additional profiling - Ongoing identification of bottlenecks
- [ ] Memory allocation monitoring - Monitor object creation in hot paths
- [ ] CSS selector edge case refinement - Advanced structural pseudo-class combinations

## Completed Recently (March 2026)

- [x] **Final CSS Compositing Properties Sprint (March 31, 2026)** - Fixed all 10 analyzer warnings (dead code removal), implemented enable-background, color-interpolation-filters, isolation:isolate CSS properties, 14 new tests, 4,896 tests passing, 0 warnings:
  - Dead code removal: 6 clip/mask methods, 6 bidi text methods, 3 unused class params, 1 test variable
  - enable-background: new - saveLayer compositing + background context push/pop for child filter BackgroundImage
  - color-interpolation-filters - CSS cascade resolution + sRGB↔linearRGB pixel-level conversion with LUT tables
  - isolation: isolate - stacking context boundary + implicit isolation for group mix-blend-mode

- [x] **Advanced Parity Sprint (March 31, 2026)** - 8 tasks completed, ~548 new tests added, parity ~95-96% → ~96-97%, 4,882 tests passing:
  - Unicode normalization and complex script text (NFC, Arabic/Thai/Devanagari/CJK detection, grapheme cluster hit-testing) - 25 tests
  - Advanced bi-directional text edge cases (BDO element, unicode-bidi interaction, mixed RTL/LTR reordering) - 18 tests
  - CSS cascade through use/symbol shadow boundary (selector matching, nested inheritance, transform stacking, event retargeting) - 20 tests
  - Use element in clip-path/mask (use resolution, symbol viewBox in mask, objectBoundingBox coordinates) - 19 tests
  - Filter input-graph advanced chains (multi-reference caching, FillPaint/StrokePaint sources, cycle prevention) - 23 tests
  - Filter primitive edge cases (feTurbulence tile stitching, feDisplacementMap bilinear interpolation, feComponentTransfer clamping) - 76 tests
  - Advanced clip/mask composition (cascading clip-paths, luminance mask formula, maskContentUnits transitions) - 16 tests
  - Blink-style regression test suite - 351 new regression tests

- [x] **Wire Edge Case Methods & Optimization Sprint (March 31, 2026)** - Wired all 12 staged methods into active render pipeline (mask cache keys, nested mask intersection, foreignObject nested SVG transforms, text accumulated transforms, textLength distribution, bidi context/direction, hit test exclusion with pointer-events, CSS shorthand guard), added 93 new tests, reduced analyzer warnings from 13→1, performance optimizations (cache eviction policies with size limits, in-place matrix ops, regex reduction). All 4,496 tests pass, parity ~94-95% → ~95-96%.
- [x] **Render Pipeline & Golden Test Sprint (March 30, 2026)** - Integrated edge case methods (data URI validation, mask animation tracking, gradient-aware luminance masking, alpha threshold hit testing), fixed all golden test failures (25 passing), expanded golden test coverage (19 new fixtures, 44 total), modularized 3 large files into 7 part files, verified filter light sources and input-graph semantics (32 new tests). All 4,403 tests pass.
- [x] **Code Modularization** - `animated_svg_painter.dart` split from 941→190 lines into 3 part files (cache, types, text_types); `animated_svg_picture.dart` split from 627→194 lines into 5 part files (diagnostics, foreign_object, types, events, lifecycle). All 4,310 tests pass, 0 analyzer errors.
- [x] **Performance Benchmarking Suite** - 5 new benchmark files (filter_chain, text_render, animation_render, combined_worst_case, memory), CacheStats class for cache profiling (hit rate, eviction count, peak size), benchmark runner sections 6-10 added.
- [x] **Text/Mask/Image Edge Cases** - 21 new tests: deeply nested tspan transforms, bidi in complex hierarchies, textLength distribution, radial gradient luminance masks, filter chains on mask content, mask-to-mask intersection, image error state fallback, nested SVG in foreignObject with preserveAspectRatio variants.
- [x] Filter & Clipping edge cases complete (~105+ new tests, parity ~89-90% → ~91-92%)
  - feMorphology edge modes (duplicate/wrap/none, zero radius, fractional radius) - 7 tests
  - feTurbulence seamless stitchTiles algorithm - 12 tests
  - Advanced filter input-graph semantics (FillPaint/StrokePaint, recursive chains)
  - Advanced use/symbol inheritance (CSS cascade, visibility/display, clipPath/mask) - 19 tests
  - Advanced clipping semantics (text clipping, nested clipPaths, mixed units) - 67 tests
- [x] Edge Case Sprint complete (~206 new tests, parity ~82% → ~89-90%)
- [x] All 17 FE primitives implemented (~99% filter parity)
- [x] Advanced Clipping/Masking (full Blink parity)
- [x] use/symbol Inheritance with CSS cascade
- [x] Light Sources with per-pixel lighting math
- [x] Component Transfer (all 5 function types)
- [x] Advanced animateMotion (~97% SMIL parity)
- [x] Text & Typography (~99% parity)
- [x] CSS structural pseudo-classes (`:nth-child`, `:first-child`, etc.)
- [x] CSS custom properties and calc() support
- [x] Multiple code modularization refactors (see CURRENT_STATUS.md)

## P0 - Blink Parity Foundations (COMPLETE)

All P0 items have been completed. See CURRENT_STATUS.md for details.

## P1 - Core Feature Gaps (COMPLETE)

All P1 items have been completed. See CURRENT_STATUS.md for details.

## P2 - Filters (COMPLETE)

All 17/17 FE primitives implemented (~97% filter parity). See CURRENT_STATUS.md for details.

## P3 - CSS/Timing Parity (COMPLETE)

All P3 items have been completed. See CURRENT_STATUS.md for details.

## P4 - Quality

- [x] Add parity regression suite based on Blink-style fixtures.
- [x] Add performance benchmarks for new renderer coverage.
- [x] Add playground import of exported JSON report bundles.
- [x] Add playground analyzer/trace-store unit tests in `test/playground/**`.
- [x] Add playground widget tests for log filters/search and problem grouping UI behavior.

## Notes

- Full Blink parity reference and scope are documented in:  
  `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`
- Closed bugs and closed milestones must be recorded in:
  `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`
