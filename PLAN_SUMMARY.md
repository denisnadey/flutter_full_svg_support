# Plan Summary (Living)

**Updated:** March 13, 2026

This file is a compact execution summary.

- Factual state: [CURRENT_STATUS.md](CURRENT_STATUS.md)
- Active backlog: [TODO.md](TODO.md)
- Closed bug classes: [docs/RESOLVED_ISSUES.md](docs/RESOLVED_ISSUES.md)

## What Is Closed

- `autoPlay: false` rendering bug: closed and regression-tested.
- `calcMode="paced"` distances for `path`/`transform`: closed and regression-tested.
- Refactor milestones (API preserved):
  - `smil_animation` split
  - `smil_parser` split
  - `smil_timeline` split
  - `css_to_smil_converter` split

## Current Focus

1. Advanced filter graph semantics (`feDropShadow`, `feMerge`, non-source/background chains).
2. Advanced text parity (`text`/`tspan`/`textPath` edge semantics).
3. Advanced hit-testing parity (`clipPath`/`mask`/`use`/text geometry).
4. Advanced `<use>`/`<symbol>` inheritance parity.
5. CSS/SMIL edge-case regression fixtures.

## Execution Rules

1. Test-first for all behavioral changes.
2. No closed issue should be re-opened without a failing regression test.
3. After each completed item, update:
   - `CURRENT_STATUS.md`
   - `TODO.md`
   - `docs/RESOLVED_ISSUES.md` (if it closes a bug class)

## Validation Commands

```bash
./.fvm/flutter_sdk/bin/flutter analyze
./.fvm/flutter_sdk/bin/flutter test
```

## Latest Baseline

- Last full validation: March 13, 2026
- `flutter test`: All tests passed (`+691 ~1`)
- `flutter analyze`: 26 info, 0 errors, 0 warnings
