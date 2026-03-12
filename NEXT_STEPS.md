# Next Steps

**Last Updated:** March 12, 2026

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Immediate (Execution Order)

1. Add next non-trivial filter semantics (advanced `feDisplacementMap` graph semantics and broader background input parity), keeping current graph-based baseline behavior.
2. Extend `feMerge` / `feMergeNode` beyond baseline into advanced non-source input-graph composition semantics.
3. Expand hit-testing semantics beyond current baseline (remaining clip/mask/use units/inheritance edge cases + text edge semantics).
4. Improve structural parity (`symbol` and advanced `<use>` semantics).

## Validation After Each Step

```bash
./.fvm/flutter_sdk/bin/flutter analyze
./.fvm/flutter_sdk/bin/flutter test
```

## Definition of Progress

A task is considered complete only when:
- behavior is covered by focused tests,
- example playground demonstrates the feature,
- `CURRENT_STATUS.md` is updated if project state changed.
