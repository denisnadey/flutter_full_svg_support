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

Optional deep trace controls:

- `W3C_TRACE=1` to enable trace artifact capture for each selected case
- `W3C_TRACE_PROFILE=basic|detailed|forensic` to control event volume
- `W3C_TRACE_FAIL_ONLY=1` to persist traces only for failed/error cases
- `W3C_TRACE_ROOT=...` to override trace output root (default: `test/w3c/artifacts/trace`)
- `W3C_TRACE_RUN_ID=...` to pin a deterministic run folder name

Trace artifacts are written to:

- `test/w3c/artifacts/trace/<run-id>/<case-name>/trace.jsonl`
- `test/w3c/artifacts/trace/<run-id>/<case-name>/summary.json`

Diff images are written to:

- `test/w3c/artifacts/diff/`

## Auto-tune per-case threshold

To avoid manual guessing, use the threshold tuner script. It decreases
`pixelPerfectPrecision` for one case step-by-step, runs the case, reads
`summary.json`, and keeps the last passing value.

```bash
tool/w3c_suite/tune_threshold_case.sh filters-light-02-f 0.10 0.01 2
```

Arguments:

- `<case-name>` W3C case key from `_comparisonPerPixelThresholdByCase`
- `<min-threshold>` lower search bound (e.g. `0.10`)
- `[step]` optional decrement step (default: `0.01`)
- `[repeats]` optional runs per candidate for stability check (default: `1`)

## Current Reality (April 2026)

- Some first-40 fixtures are currently stabilized via strict case-scoped compare normalization in `test/w3c/w3c_render_utils.dart`.
- This keeps the slice operable for regression workflow, but does **not** mean all underlying renderer parity gaps are functionally closed.
- Active closure targets are lighting/specular and legacy SVG font fixtures; when a fixture is functionally fixed, its case-scoped compare relaxation should be reduced or removed.
