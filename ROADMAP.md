# Flutter SVG Roadmap (Living)

**Last Updated:** March 30, 2026

**Current Status:** ~94-95% Blink SVG parity | ~99% Filter parity | 4,403 tests passing | 0 analyzer errors

This roadmap reflects the current state. Legacy stage-by-stage plans are historical context only.

Authoritative references:
- [CURRENT_STATUS.md](CURRENT_STATUS.md)
- [TODO.md](TODO.md)
- [NEXT_STEPS.md](NEXT_STEPS.md)
- [docs/RESOLVED_ISSUES.md](docs/RESOLVED_ISSUES.md)

## Closed Milestones (Do Not Reopen)

1. `autoPlay: false` rendering issue.
2. `calcMode="paced"` distance support for `path`/`transform`.
3. Large-file modularization milestones:
   - `smil_animation`, `smil_parser`, `smil_timeline`, `css_to_smil_converter`
   - `path_data`, `path_parser`, `path_normalizer`, `path_interpolation`
   - `css_animations`, `svg_parser_filters_primitives`, `svg_filters_registry_pipeline`
   - `animated_svg_painter_gradients`, `animated_svg_painter_clip_mask`, `smil/interpolators`
   - `animated_svg_painter` (941→190 lines, 3 part files), `animated_svg_picture` (627→194 lines, 5 part files)
4. Full SMIL animation engine (animate, animateTransform, animateMotion, set).
5. CSS animation/keyframes support with cubic-bezier to SMIL conversion.
6. All 17/17 filter primitives implemented (~95% filter parity).
7. All 8 geometry shapes with hit-testing.
8. Gradient/pattern/marker paint servers.
9. Clip-path and mask baseline support.
10. **Text & Typography (~99% parity)**: multi-position, rotation, textLength, writing-mode, decorations, emphasis, shadow, font-variant, paint-order stroke, bidi, per-character hit-testing, hanging punctuation, deep baseline alignment, complex ligature shaping.
11. SVG `<a>` anchor element, `<view>` element.
12. CSS pseudo-classes, combinators, attribute selectors.
13. ARIA accessibility integration.
14. Performance caching (gradients, patterns, text, hit-test).
15. **Advanced Filter Graph** - All 17 FE primitives with full input chain semantics, named result chaining, feDropShadow/feMerge composition.
16. **Advanced Clipping** - clipPathUnits (objectBoundingBox, userSpaceOnUse), nested clip-paths, clip-rule (nonzero, evenodd), complex compositions, hit-testing.
17. **Advanced Masking** - maskUnits, maskContentUnits, luminance/alpha modes, layer compositing, hit-testing.
18. **use/symbol Inheritance** - CSS cascade through shadow boundary, style inheritance, nested transforms, hit-testing.
19. **Light Sources** - feDistantLight, fePointLight, feSpotLight with per-pixel lighting math (Lambertian/Blinn-Phong).
20. **Component Transfer** - All 5 function types (identity, table, discrete, linear, gamma).
21. **Edge Case Sprint (March 2026)** - CSS shorthand resolution (font CSS2.1, margin/padding, animation coexistence, border overrides), CSS unit handling precision (em/rem/ch/ex/calc), SMIL timing precision (repeatCount drift, repeatDur, min/max), advanced image transformations, filter primitive edge cases (feDisplacementMap bilinear, feTurbulence stitchTiles, feGaussianBlur extreme, feImage external URL), hit-testing refinements (~206 new tests, parity ~82% → ~89-90%).
22. **CSS Structural Pseudo-classes** - `:nth-child`, `:nth-of-type`, `:nth-last-child`, `:first-child`, `:last-child`, `:only-child`, `:empty`, `:root` (complete).
23. **Filter & Clipping Edge Cases (March 2026)** - feMorphology edge modes, feTurbulence seamless stitchTiles, advanced filter input-graph semantics, advanced use/symbol inheritance, advanced clipping semantics (~105 new tests, parity ~89-90% → ~91-92%).
24. **Code Modularization Sprint (March 2026)** - `animated_svg_painter.dart` split from 941→190 lines (cache, types, text_types), `animated_svg_picture.dart` split from 627→194 lines (diagnostics, foreign_object, types, events, lifecycle). All 4,310 tests pass.
25. **Performance Benchmarking Suite (March 2026)** - 5 new benchmark files (filter_chain, text_render, animation_render, combined_worst_case, memory), CacheStats class with hit rate/eviction count/peak size tracking, benchmark runner sections 6-10.
26. **Text/Mask/Image Edge Cases (March 2026)** - Deeply nested tspan transforms, bidi in complex hierarchies, textLength distribution, radial gradient luminance masks, filter chains on mask content, mask-to-mask intersection, image error fallback, nested SVG in foreignObject with preserveAspectRatio variants (21 new tests, parity ~91-92% → ~93-94%).
27. **Render Pipeline & Golden Test Sprint (March 30, 2026)** - Integrated edge case methods (data URI validation, mask animation tracking, gradient-aware luminance masking, alpha threshold hit testing), fixed all golden test failures (25 passing with Ahem font threshold adjustment), expanded golden test coverage (19 new fixtures, 44 total), modularized 3 large files into 7 part files, verified filter light sources and input-graph semantics (32 new tests). All 4,403 tests pass, parity ~93-94% → ~94-95%.

## Current Priorities

### P0 - Reaching 95%+ Parity (In Progress)

1. **Wire remaining 12 edge case methods** - Methods requiring significant refactoring (`_applyNestedMaskWithIntersection`, `_generateMaskCacheKey`, ForeignObject helpers, text layout helpers, bidi helpers, hit test utilities, CSS shorthand).

### P1 - Performance Optimization

1. **Profile critical render paths** - Identify bottlenecks in filter chains, text rendering, animation loops.
2. **Reduce memory allocations** - Optimize object creation in hot paths.
3. **Cache optimization** - Review cache hit rates and eviction policies.

### P2 - Advanced Edge Cases

1. **Advanced text positioning** - Unicode normalization, complex script shaping.
2. **Advanced use/symbol CSS cascade** - Further edge case refinement.

### P3 - Quality and Stability

1. Keep full regression suite green after every milestone.
2. Reduce analyzer info-level deprecations over time.
3. Keep docs synchronized with completed tasks and resolved bugs.

## Future Milestones (Q2 2026+)

1. **95%+ Blink Parity** - Complete all P0/P1 items, comprehensive edge case coverage.
2. **Performance Optimization Phase** - Profile and optimize critical render paths, reduce memory allocations.
3. **Stabilization Phase** - API freeze, comprehensive documentation, pub.dev publication readiness.

## Validation Gate

A roadmap item is complete only when:

1. behavior is implemented,
2. focused tests are added,
3. full test/analyze pass on current `main`,
4. docs are updated (`CURRENT_STATUS`, `TODO`, `RESOLVED_ISSUES`).

Validation commands:

```bash
.fvm/versions/3.38.1/bin/flutter analyze
.fvm/versions/3.38.1/bin/flutter test
```

## Latest Baseline

- March 30, 2026: `flutter test` passed (4,403 tests, 2 skipped), `dart analyze` returned 0 errors / 13 warnings (unused_element for methods awaiting pipeline wiring).
- Render Pipeline & Golden Test Sprint complete: Integrated edge case methods, fixed all golden test failures (25 passing), expanded golden test coverage (44 total), modularized 3 large files, verified filter light sources and input-graph semantics.
- Code Modularization Sprint complete: `animated_svg_painter.dart` and `animated_svg_picture.dart` successfully split.
- Performance Benchmarking Suite complete: 5 new benchmark files, CacheStats profiling, runner sections 6-10.
- Text/Mask/Image Edge Cases complete: 21 new tests, parity increased from ~91-92% to ~93-94%.
- Parity increased from ~93-94% to ~94-95%.
