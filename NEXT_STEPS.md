# Next Steps

**Last Updated:** March 16, 2026

Authoritative status is maintained in:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen registry:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

Detailed Blink gap matrix:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/BLINK_PARITY_AUDIT.md`

## Immediate (Execution Order)

1. Expand advanced filter graph semantics (`feDropShadow`, `feMerge`/`feMergeNode`, non-source/background input parity).
2. Close advanced text parity gaps (`text`/`tspan`/`textPath` typography and positioning details).
3. Expand advanced hit-testing semantics (`clipPath`/`mask`/`use` and text geometry edge cases).
4. Improve advanced `<use>`/`<symbol>` inheritance semantics.
5. Add targeted regression fixtures for CSS/SMIL edge cases (timing/transform shorthand corner cases).
6. Continue modular refactor of remaining large files (for AI/dev velocity) with API-stability and full regression checks after each split.
   Closed in this iteration: `animated_svg_painter_gradients.dart`, `animated_svg_painter_clip_mask.dart`, `smil/interpolators.dart`, `css_to_smil_converter_transforms.dart`.
   Current priority targets: `svg_filters_primitives.dart`, `animated_svg_painter_shapes.dart`, `animated_svg_picture.dart`, `animated_svg_picture_utils.dart`.

## Validation After Each Step

```bash
./.fvm/flutter_sdk/bin/flutter analyze
./.fvm/flutter_sdk/bin/flutter test
```

## Definition of Progress

A task is complete only when:
- behavior is covered by focused tests,
- example/playground demonstrates the feature if UI-visible,
- `CURRENT_STATUS.md` is updated if factual state changed,
- `docs/RESOLVED_ISSUES.md` is updated for closed bug classes.
