# Flutter SVG Roadmap (Living)

**Last Updated:** March 28, 2026

**Current Status:** ~80% Blink SVG parity | ~95% Filter parity | 3,538 tests passing | 0 analyzer warnings

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

## Current Priorities

### P0 - Parity Foundations (In Progress)

1. **Advanced animateMotion semantics** - SMIL 88% → 92% (complex path timing, keyPoints precision, rotate attribute edge cases).
2. **CSS/SMIL edge-case parity** - Complex shorthand resolution, unit handling, timing precision.
3. **External content edge cases** - Advanced image transformations, nested foreignObject (60% → 75%).
4. **Code modularization** - Splitting large files for dev velocity.

### P1 - Core Feature Expansion

1. ~~Advanced text typography/positioning parity.~~ (Complete - ~99% parity)
2. ~~`foreignObject` and `image` semantics beyond baseline.~~ (Complete)
3. ~~`animateMotion` parity beyond current baseline behavior.~~ (Complete)

### P2 - CSS/Timing Fidelity

1. CSS transform/timing edge-case parity (complex shorthand and units).
2. Expand regression fixture coverage for CSS->SMIL conversion.

### P3 - Quality and Stability

1. Keep full regression suite green after every milestone.
2. Reduce analyzer info-level deprecations over time.
3. Keep docs synchronized with completed tasks and resolved bugs.

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

- March 28, 2026: `flutter test` passed (3,538), `dart analyze` returned 0 errors / 0 warnings / 0 info.
