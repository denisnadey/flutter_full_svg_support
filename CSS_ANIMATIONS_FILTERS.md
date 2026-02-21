# CSS Animations & SVG Filters - Notes

**Last Updated:** February 21, 2026

For authoritative status, use:
- `/Users/denisnadey/apps/flutter_full_svg_support/CURRENT_STATUS.md`

## Implemented

### SVG Filters
- `feGaussianBlur`
- `feDropShadow` (currently simplified)
- `feColorMatrix`

### CSS Animations
- `@keyframes` parsing
- `animation` / `animation-*` parsing
- CSS keyframes conversion into SMIL animation objects
- Integration through `SmilParser.parseAnimations()`

## Remaining parity gaps

- Full `feDropShadow` composition behavior.
- CSS conversion parity for `transform` functions, `cubic-bezier(...)`, and `alternate*` direction modes.

## Key files

- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/css_animations.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/css_to_smil_converter.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/smil/smil_parser.dart`
- `/Users/denisnadey/apps/flutter_full_svg_support/lib/src/animation/svg_filters.dart`
