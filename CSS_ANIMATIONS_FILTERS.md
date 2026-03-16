# CSS Animations & SVG Filters - Notes

**Last Updated:** March 13, 2026

For authoritative status, use:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

Closed issues / do-not-reopen:
- `/Users/denisnadey/apps/flutter_full_svg_support/docs/RESOLVED_ISSUES.md`

## Implemented

### CSS Animations
- `@keyframes` parsing
- `animation` / `animation-*` parsing
- Conversion into SMIL animation objects
- Integration through `SmilParser.parseAnimations()`
- Baseline CSS transform normalization (function aliases, angle units, numeric normalization)
- Timing conversion: `cubic-bezier(...)`, `ease*`, and per-keyframe timing handling
- Direction runtime behavior: `reverse`, `alternate`, `alternate-reverse`

### SVG Filters (Animated Pipeline, Baseline)
- `feGaussianBlur`, `feMorphology`, `feDisplacementMap`, `feImage`, `feConvolveMatrix`
- `feTurbulence`, `feComponentTransfer`, `feDiffuseLighting`, `feSpecularLighting`
- `feOffset`, `feFlood`, `feBlend`, `feComposite`, `feMerge`, `feTile`
- `feDropShadow`, `feColorMatrix`

## Remaining parity gaps

- Advanced filter input-graph and composition semantics (non-source/background chains).
- Advanced `feDropShadow` and `feMerge` parity beyond baseline behavior.
- CSS conversion edge cases for complex shorthand/transform fidelity.

## Key files

- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/css_animations.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/css_to_smil_converter.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/css_to_smil_converter_core.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/css_to_smil_converter_timing.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/css_to_smil_converter_transforms.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/smil/smil_parser.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/svg_filters.dart`
