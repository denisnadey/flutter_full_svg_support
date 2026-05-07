## 1.0.3

- Fix `<image>` aspect ratio: when only `width` or `height` is specified, the missing dimension is now computed proportionally from the image's intrinsic size. Previously, the raw pixel dimension was used, causing images placed with a single size attribute to shift position and appear at incorrect scale.
- Fix `background-color` clipping with `clipToViewBox=true`: the SVG root `background-color` style was drawn before the viewBox clip was applied, causing it to fill the entire widget instead of being bounded by the SVG viewport. It is now drawn inside the transformed and clipped canvas context, matching browser behaviour.
- Add `clipToViewBox` toggle (default `true`) to the example playground, so SVG content that overflows the viewBox boundary is clipped by default — matching how browsers display SVG files opened directly.
- Fix playground SVG proportions: preview width and height are now derived from the SVG `viewBox` aspect ratio instead of forcing a square container, so portrait or landscape SVGs display at correct proportions.

## 1.0.2

- Add native `file://` URI support for `<image>` elements: local files load via `dart:io` on all non-web platforms. Web stub returns null gracefully.
- Improve pub.dev package description and topics for animated SVG discoverability.
- Rewrite README: clear animated-SVG positioning, comparison table, migration guide, SVGator notes, FAQ, and supported-features matrix.
- Add `docs/` directory: migration guide, feature compatibility matrix, limitations, and SEO notes.
- Add marketing article drafts in `docs/marketing/`.

## 1.0.1

* Fix filter rendering on `<g>` groups: filters applied to `<g>` elements with no opacity or blend-mode were silently discarded. Now correctly opens a `saveLayer` with the filter, improving fidelity for SVGs that animate filter primitives on groups.
* Fix SMIL sandwich model for multiple animations targeting the same attribute: additive animations no longer double-stack when chained via `computeRawValue` + `applyAdditiveWithBase`.
* Add `clipToViewBox` option to `AnimatedSvgPicture` and `AnimatedSvgPainter`: opt-in strict viewBox clipping to match browser direct-URL rendering behaviour (defaults to `false` for backward compatibility).
* Widen `xml` dependency constraint from `^6.0.0` to `>=6.0.0 <8.0.0` to support xml 7.x.
* Fix deprecated `FontWeight.index` usage — replaced with `FontWeight.value`.

## 1.0.0

* Initial release of `full_svg_flutter` — a comprehensive SVG rendering library for Flutter.
