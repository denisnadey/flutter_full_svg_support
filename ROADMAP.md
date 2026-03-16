# Flutter SVG Animation Roadmap (Living)

**Last Updated:** March 16, 2026

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
   - `smil_animation`
   - `smil_parser`
   - `smil_timeline`
   - `css_to_smil_converter`

## Current Priorities

### P0 - Parity Foundations

1. Advanced filter input-graph semantics (`feDropShadow`, `feMerge`, background/non-source chains).
2. Advanced hit-testing parity (`clipPath`/`mask`/`use`/text geometry).
3. Advanced `<use>`/`<symbol>` inheritance behavior.

### P1 - Core Feature Expansion

1. Advanced text typography/positioning parity.
2. `foreignObject` and `image` semantics beyond baseline.
3. `animateMotion` parity beyond current baseline behavior.

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

- March 13, 2026: `flutter test` passed (`+691 ~1`), `flutter analyze` returned 26 info / 0 errors / 0 warnings.
