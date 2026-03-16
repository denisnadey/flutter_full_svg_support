# Quick Start Guide (Current)

**Last Updated:** March 13, 2026

This guide is intentionally short and aligned with current project state.

## 1. Read First

1. [CURRENT_STATUS.md](CURRENT_STATUS.md)
2. [TODO.md](TODO.md)
3. [NEXT_STEPS.md](NEXT_STEPS.md)
4. [docs/RESOLVED_ISSUES.md](docs/RESOLVED_ISSUES.md)

## 2. Verify Local Health

Run in project root:

```bash
./.fvm/flutter_sdk/bin/flutter analyze
./.fvm/flutter_sdk/bin/flutter test
```

Expected baseline (March 13, 2026):
- tests: all pass (`+691 ~1`)
- analyze: 26 info, 0 errors, 0 warnings

## 3. Active Work Order

1. Advanced filter graph semantics (`feDropShadow`, `feMerge`, non-source/background chains)
2. Advanced text parity (`text` / `tspan` / `textPath` edge semantics)
3. Advanced hit-testing parity (`clipPath` / `mask` / `use` / text geometry)
4. Advanced `<use>` / `<symbol>` inheritance semantics
5. CSS/SMIL regression fixtures for edge cases

## 4. Before You Start a New Task

1. Confirm the issue is not already closed in `docs/RESOLVED_ISSUES.md`.
2. Add/adjust failing test first.
3. Implement fix/refactor.
4. Re-run analyze + tests.
5. Update docs (`CURRENT_STATUS`, `TODO`, and `RESOLVED_ISSUES` when relevant).

## 5. Useful Paths

- SMIL core: `lib/src/animation/smil/`
- CSS animation conversion: `lib/src/animation/css_to_smil_converter*.dart`
- Animated rendering: `lib/src/animation/animated_svg_painter*.dart`
- Parser: `lib/src/animation/svg_parser*.dart`
- Tests: `test/animation/`

## 6. Commands You Will Use Most

```bash
# full validation
./.fvm/flutter_sdk/bin/flutter analyze
./.fvm/flutter_sdk/bin/flutter test

# targeted tests
./.fvm/flutter_sdk/bin/flutter test test/animation/

# example app
cd example && ../.fvm/flutter_sdk/bin/flutter run
```
