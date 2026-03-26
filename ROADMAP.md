# Flutter SVG Animation Roadmap (Living)

**Last Updated:** March 26, 2026

**Current Status:** ~74% Blink SVG parity | 3099 tests passing | 0 analyzer warnings

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
6. 17/25 filter primitives implemented.
7. All 8 geometry shapes with hit-testing.
8. Gradient/pattern/marker paint servers.
9. Clip-path and mask baseline support.
10. Advanced text: multi-position, rotation, textLength, writing-mode.
11. SVG `<a>` anchor element, `<view>` element.
12. CSS pseudo-classes, combinators, attribute selectors.
13. ARIA accessibility integration.
14. Performance caching (gradients, patterns, text, hit-test).

## Current Priorities

### P0 - Parity Foundations (In Progress)

1. **Light Sources** - Advanced feSpecularLighting/feDiffuseLighting positioning.
2. **Component Transfer** - Extended feComponentTransfer channel functions.
3. **Filter Input-Graph** - Advanced non-source/background input chain semantics.
4. **use/symbol Inheritance** - Style and attribute inheritance edge cases.
5. **Advanced Clipping** - Complex clip-path compositions.
6. **Advanced Masking** - Luminance masks and alpha channel handling.
7. **Advanced Typography** - Remaining text layout edge cases.

### P1 - Core Feature Expansion

1. ~~Advanced text typography/positioning parity.~~ (Baseline complete)
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
./.fvm/flutter_sdk/bin/flutter analyze
./.fvm/flutter_sdk/bin/flutter test
```

## Latest Baseline

- March 26, 2026: `flutter test` passed (+3099), `flutter analyze` returned 0 errors / 0 warnings.
