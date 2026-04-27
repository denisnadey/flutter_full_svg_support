## 1.0.1

* Fix filter rendering on `<g>` groups: filters applied to `<g>` elements with no opacity or blend-mode were silently discarded. Now correctly opens a `saveLayer` with the filter, improving fidelity for SVGs that animate filter primitives on groups.
* Fix SMIL sandwich model for multiple animations targeting the same attribute: additive animations no longer double-stack when chained via `computeRawValue` + `applyAdditiveWithBase`.
* Add `clipToViewBox` option to `AnimatedSvgPicture` and `AnimatedSvgPainter`: opt-in strict viewBox clipping to match browser direct-URL rendering behaviour (defaults to `false` for backward compatibility).
* Widen `xml` dependency constraint from `^6.0.0` to `>=6.0.0 <8.0.0` to support xml 7.x.
* Fix deprecated `FontWeight.index` usage — replaced with `FontWeight.value`.

## 1.0.0

* Initial release of `full_svg_flutter` — a comprehensive SVG rendering library for Flutter.
