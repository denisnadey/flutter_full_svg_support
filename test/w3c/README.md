# W3C Static Visual Suite

Phase-1 integration for `W3C_SVG_11_TestSuite`.

## What is covered

The manifest includes only deterministic static cases:

- `status == accepted`
- operator script contains `No interaction required`
- no animation tags (`animate`, `set`, etc.)
- no `<script>` tags (DOM/JS-dependent behavior)
- no CSS2 system color keywords (`Window`, `MenuText`, etc.)
- no ambiguous pass criteria (e.g. "might not match reference image")
- no pass criteria that explicitly allow text/labeling variance
- `viewBox == 0 0 480 360`
- only `.svg` fixtures

## Regenerate manifest

```bash
python3 tool/w3c_suite/build_static_manifest.py
```

Generated file:

- `test/w3c/manifest/w3c_static_accepted_manifest.json`

## Run tests

Skipped by default to avoid slowing full local/CI runs.

Run full static suite:

```bash
RUN_W3C_STATIC=1 ./.fvm/flutter_sdk/bin/flutter test test/w3c/w3c_static_golden_test.dart
```

Run a quick sample:

```bash
RUN_W3C_STATIC=1 W3C_LIMIT=20 ./.fvm/flutter_sdk/bin/flutter test test/w3c/w3c_static_golden_test.dart
```

Run a targeted fixture by substring:

```bash
RUN_W3C_STATIC=1 W3C_LIMIT=1 W3C_NAME_FILTER=shapes-rect-01-t ./.fvm/flutter_sdk/bin/flutter test test/w3c/w3c_static_golden_test.dart
```

Optional debugging controls:

- `W3C_DEBUG=1` to print per-stage logs (`capture`/`compare`)
- `W3C_CASE_TIMEOUT_SECS=75` to override per-case timeout (default: 120s)

Diff images are written to:

- `test/w3c/artifacts/diff/`
