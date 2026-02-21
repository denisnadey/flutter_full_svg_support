# Next Steps

**Last Updated:** February 21, 2026

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Immediate (Execution Order)

1. Add next non-trivial filter primitives (`feBlend`, `feComposite`, `feFlood`).
2. Expand hit-testing semantics beyond current baseline (clip/mask/use-aware regions + text).
3. Complete CSS conversion gaps (`transform`, `cubic-bezier`, `alternate*`).
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
