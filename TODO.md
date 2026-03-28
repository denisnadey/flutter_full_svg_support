# TODO - Animation Work Queue

**Last Updated:** March 29, 2026  
**Status Source:** `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`  
**Closed Issues Registry:** `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

**Current Status:** ~93-94% Blink parity | ~99% Text parity | ~99% Filter parity | ~97% SMIL parity | 4,330+ tests passing | 0 analyzer warnings

This file tracks actionable implementation tasks.
For factual project status, use `CURRENT_STATUS.md` only.

## Current Sprint (P0 - Active)

- [ ] **Integrate edge case methods into render pipeline** - Wire up new edge case utility methods into active render path callsites
- [ ] **Address pre-existing golden test failures** - Fix known failing golden tests
- [ ] **Expand golden test coverage** - Additional regression fixtures for edge cases
- [ ] **Further modularization** - Remaining large files: `text_layout` (785 lines), `text_style_positioning` (679 lines), `clip_mask_advanced` (715+ lines)

## Completed Recently (March 2026)

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

- [ ] Add parity regression suite based on Blink-style fixtures.
- [x] Add performance benchmarks for new renderer coverage.
- [x] Add playground import of exported JSON report bundles.
- [x] Add playground analyzer/trace-store unit tests in `test/playground/**`.
- [x] Add playground widget tests for log filters/search and problem grouping UI behavior.

## Notes

- Full Blink parity reference and scope are documented in:  
  `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`
- Closed bugs and closed milestones must be recorded in:
  `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`
