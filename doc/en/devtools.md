# FullSVG DevTools Inspector

The FullSVG Inspector is the official Flutter DevTools companion extension for
`full_svg_flutter`. It connects to a running debug Flutter application and
inspects the real `SvgDocument`, animation timeline, and painter owned by every
currently mounted FullSVG renderer.

The bridge is debug-only. It requires no application configuration and does not
register renderers, retain DOM trees, or collect inspector data in release
builds.

## Requirements

- Flutter 3.32 or newer.
- A debug Flutter application that depends on `full_svg_flutter`.
- A current Flutter DevTools version with extensions enabled.
- At least one `FSvgPicture`, `SvgPicture`, or `AnimatedSvgPicture` must have
  mounted once so the package can register its VM service extensions.

## Open the inspector

1. Run the application in debug mode.
2. Open Flutter DevTools from the IDE or the `flutter run` output.
3. Enable DevTools extensions when prompted. Extension enablement is stored by
   DevTools and may need to be approved again after package or SDK changes.
4. Select the `full_svg_flutter` extension. The embedded inspector identifies
   itself as **FullSVG**.

The extension reconnects to the main isolate after hot restart. Hot reload
preserves mounted renderer identities where Flutter preserves their `State`
objects. A disposed renderer disappears on the next instance refresh.

## Instance inspector

The left pane lists every live renderer independently, including identical SVG
assets mounted more than once. Each row shows its source label, animation state,
and DOM node count. IDs such as `svg-1` are stable only for that renderer's
mounted lifetime and are never derived from `hashCode`.

The registry stores weak references and also unregisters deterministically from
the renderer lifecycle, preventing DevTools from keeping removed routes or list
items alive.

## DOM inspector

The middle pane exposes the live SVG DOM. Child nodes load only when a tree row
is expanded, so opening a large document does not repeatedly serialize every
attribute or path. Debug node IDs such as `n1` and `n2` remain stable for the
lifetime of that parsed document and do not depend on authored `id` attributes.

Selecting a node loads its details on demand:

- tag, SVG ID, classes, child count, and debug node ID;
- raw and current resolved attribute values;
- whether an attribute currently has an animated value;
- basic SMIL/CSS animation descriptors that target the node.

Long values such as path `d` data remain selectable and are not permanently
truncated.

## Playback controls

For a renderer with a parsed animation timeline, the bottom toolbar controls
the renderer's existing deterministic clock:

- play or pause;
- restart (seek to zero);
- seek to an arbitrary timestamp;
- playback rates from 0.25× to 2×.

Slider updates are throttled while dragging and the final pointer-release value
is always sent exactly. The inspector does not create a second animation
timeline. If an SVG was mounted with `autoPlay: false`, the runtime creates its
Flutter ticker lazily only when DevTools asks it to play.

## Node highlighting

Selecting a DOM node outlines it in the running application without modifying
SVG attributes. Shapes and paths use their real render geometry. Containers and
text use the rendering engine's computed geometry bounds, including inherited
child transforms. Clearing the property selection removes the overlay.

The overlay is a debug paint pass and can appear in a screenshot captured while
highlighting is active. Highlighting definition nodes and content rendered
through multiple `<use>` instances is currently best-effort; interactive use
instance picking is planned separately.

## Runtime statistics

The Stats section reports values that are already reliable and cheap to obtain:
DOM nodes, animation counts, active animations, filter primitives, masks,
gradients, clip paths, JavaScript presence, current time, and duration. It does
not invent parse, layout, paint, filter, or JS timings that the renderer does
not currently measure.

## Limitations

- Service-extension calls require the main isolate to be running rather than
  paused at a breakpoint.
- JavaScript presence is reported, but arbitrary JS evaluation is deliberately
  not exposed through the DevTools protocol.
- Computed CSS and cascade provenance are not yet exposed.
- `<use>` instance selection, path control-point editing, and performance frame
  timings are future work.
- Polling is used for the MVP: instance summaries refresh every two seconds and
  selected playback state every 500 ms. Full DOM data is never polled.

## Troubleshooting

**No Flutter application connected**

Attach DevTools to a running debug Flutter application.

**FullSVG debugging is unavailable**

Confirm the app uses this package version, is running in debug mode, and has
mounted a FullSVG renderer. Resume the isolate if it is paused, then press
Retry.

**No mounted FullSVG instances**

Navigate to a route that renders an SVG. The example app includes
**FullSVG DevTools** under Demos for this purpose.

**The extension is not listed**

Enable DevTools extensions and run `dart run tool/devtools.dart all` when
developing from this repository. For a pub dependency, ensure the package was
resolved after upgrading and restart DevTools.

## Extension development workflow

The runtime bridge and protocol DTOs live under `lib/src/debug`. The independent
Flutter Web source is in `packages/full_svg_devtools_extension`; only the built
artifact is published under `extension/devtools/build`.

From the repository root:

```bash
# pub get, official build_and_copy, then official validation
dart run tool/devtools.dart all

# validate an existing build only
dart run tool/devtools.dart validate

# run in the package's simulated DevTools environment
dart run tool/devtools.dart simulate

# extension unit/widget tests
cd packages/full_svg_devtools_extension
../../.fvm/flutter_sdk/bin/flutter test
```

Before release, also run:

```bash
./.fvm/flutter_sdk/bin/flutter analyze
./.fvm/flutter_sdk/bin/flutter test
./.fvm/flutter_sdk/bin/dart pub publish --dry-run
```

The root `.pubignore` excludes the extension source package and includes
`extension/devtools/config.yaml` plus the validated web build automatically.
