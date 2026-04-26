# W3C Goldens Tooling

## Files

- `generate_manifest.js` — builds `w3c_manifest.json` from W3C approved harness index.
- `capture_browser_w3c.js` — captures browser PNG baselines from manifest cases.
- `run_w3c_comparison.sh` — orchestrates browser capture + Flutter comparison test.
- `analyze_report.js` — builds Markdown diagnostics from JSON test report.
- `calibrate_thresholds.js` — lowers per-case thresholds from a measured JSON report.
- `w3c_manifest.json` — generated manifest consumed by the test suite.

## Commands

```bash
# 1) Generate/update manifest
node tool/w3c_goldens/generate_manifest.js

# 2) Capture browser baselines for smoke tier
node tool/w3c_goldens/capture_browser_w3c.js --tier smoke --update-baseline

# 3) Run Flutter comparison tests for smoke tier
W3C_TIER=smoke ./.fvm/flutter_sdk/bin/flutter test \
  test/golden_comparison/w3c_golden_comparison_test.dart \
  --tags w3c_golden

# Or run full orchestration
./tool/w3c_goldens/run_w3c_comparison.sh --tier smoke --update-baseline

# Enable Flutter-side pixel comparison (experimental)
./tool/w3c_goldens/run_w3c_comparison.sh --tier smoke --enable-render

# Exploratory run without failing on threshold mismatches
./tool/w3c_goldens/run_w3c_comparison.sh \
  --tier smoke \
  --enable-render \
  --no-enforce-threshold

# Full diagnostics for all tiers
./tool/w3c_goldens/run_w3c_comparison.sh \
  --tier all \
  --enable-render \
  --no-enforce-threshold

# Calibrate thresholds from the latest full measured report
node tool/w3c_goldens/calibrate_thresholds.js \
  --report test/goldens/w3c/reports/w3c_report_all_YYYYMMDD_HHMMSS.json \
  --margin 0.02

# Strict full run after calibration
./tool/w3c_goldens/run_w3c_comparison.sh \
  --tier all \
  --skip-browser \
  --enable-render
```

## Filters

- `--tier smoke|core|extended|all`
- `--case <id>`
- `--limit <n>`
- `--enable-render`
- `--no-enforce-threshold`
- `--debug-trace`
- `--use-animated-renderer`
- `--use-static-renderer` (default)

Test env vars (for `w3c_golden_comparison_test.dart`):

- `W3C_TIER`
- `W3C_CASE`
- `W3C_LIMIT`
- `W3C_INCLUDE_SKIPPED=true`
- `W3C_ENABLE_RENDER=true`
- `W3C_ENFORCE_THRESHOLD=false` (collect results without `expect` failure)
- `W3C_DEBUG_TRACE=true` (verbose per-step logging)
- `W3C_USE_ANIMATED_RENDERER=false` (default; use `SvgPicture` renderer)
- `W3C_USE_ANIMATED_RENDERER=true` (switch to `AnimatedSvgPicture`)
- `W3C_REPORT_JSON=/abs/path/report.json` (diagnostic JSON output path)

Script env var:

- `FLUTTER_BIN=/abs/path/to/flutter` (forces Flutter binary for `run_w3c_comparison.sh`)

Reports are saved under:

- `test/goldens/w3c/reports/*.json`
- `test/goldens/w3c/reports/*.md`

## CI Gates

Workflow: `.github/workflows/w3c-goldens.yml`

- PR / push (`main|master`): strict smoke gate
  - `./tool/w3c_goldens/run_w3c_comparison.sh --tier smoke --skip-browser --enable-render`
- Nightly (`schedule`) and manual (`workflow_dispatch`): strict full gate
  - `./tool/w3c_goldens/run_w3c_comparison.sh --tier all --skip-browser --enable-render`

Both jobs upload reports as CI artifacts.
