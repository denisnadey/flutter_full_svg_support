# W3C Gap Closure Plan (Chromium-Driven)

**Last Updated:** April 21, 2026

## Goal

Close remaining W3C static-suite gaps by functional renderer fixes first, then reduce per-case thresholds using measured diffs (no blind tuning).

## Where To Read Reference Behavior

- Active Chromium/Blink sources: `/Users/denisnadey/Downloads/chromium-main/third_party/blink`
- In-repo pinned Blink snapshot: `/Users/denisnadey/apps/flutter_full_svg_support/blink-b87d44f-Source-core-svg`
- Skia (needed for filter/lighting parity checks): `/Users/denisnadey/Downloads/chromium-main/third_party/skia`

If Chromium was downloaded as zip from `https://github.com/chromium/chromium/tree/main`, submodule commands do not work there. Hydrate missing paths directly:

```bash
cd /Users/denisnadey/Downloads/chromium-main
SUB=third_party/skia
URL=$(awk -v p="$SUB" '$1=="path" && $3==p {f=1;next} f&&$1=="url"{print $3;exit}' .gitmodules)
rm -rf "$SUB"
git clone --depth 1 --filter=blob:none "$URL" "$SUB"
```

Optional full git checkout with native submodule flow:

```bash
git clone --depth 1 --filter=blob:none https://github.com/chromium/chromium.git /Users/denisnadey/Downloads/chromium-main-git
cd /Users/denisnadey/Downloads/chromium-main-git
git submodule sync --recursive
git submodule update --init --recursive --depth 1 --jobs 8
```

## Current Baseline (April 21, 2026)

- First 40 static accepted cases: green.
- `W3C_LIMIT=83`: 50 pass, 33 fail.
- Fail clusters:
  - `masking-*`: 9 fails
  - `painting-*`: 17 fails
  - `paths-data-*`: 7 fails

Lowest-similarity cases in the 83-slice:

1. `masking-path-03-b` - 0.7087
2. `painting-stroke-02-t` - 0.7299
3. `painting-stroke-03-t` - 0.7383
4. `painting-fill-02-t` - 0.7572
5. `painting-stroke-04-t` - 0.7579
6. `painting-render-02-b` - 0.7676
7. `painting-marker-04-f` - 0.7972
8. `painting-marker-03-f` - 0.8023
9. `painting-fill-01-t` - 0.8171
10. `masking-path-02-b` - 0.8393

## Execution Algorithm (Fast Functional Closure)

For each case, run this loop:

1. Capture artifacts and traces:
   - `RUN_W3C_STATIC=1 W3C_LIMIT=1 W3C_NAME_FILTER=<case> W3C_TRACE=1 W3C_TRACE_PROFILE=forensic ./.fvm/flutter_sdk/bin/flutter test test/w3c/w3c_static_golden_test.dart`
2. Map mismatch to Blink behavior in Chromium source before editing.
3. Implement renderer fix in pipeline code.
4. Re-run targeted case, then the local slice (`W3C_LIMIT=83`) to confirm no regression.
5. Only then squeeze threshold with measured runs (no guessing):
   - `tool/w3c_suite/tune_threshold_case.sh <case> <min-threshold> 0.01 3`
6. If stable at lower threshold, keep it; if unstable, keep temporary threshold and open a functional follow-up item.

## Priority Waves

### Wave A (largest visual deltas first)

- `masking-path-03-b`
- `painting-stroke-02-t`
- `painting-stroke-03-t`
- `painting-fill-02-t`
- `painting-stroke-04-t`
- `painting-render-02-b`

### Wave B (cluster follow-through)

- Remaining `painting-*` fails in 41-83
- Remaining `masking-*` fails in 41-83

### Wave C (path parser/render consistency)

- `paths-data-*` set (`01..07`) as one batch to avoid piecemeal parser drift

## Definition Of Done

A case is considered closed only when all are true:

1. Case passes with functional parity behavior.
2. Threshold is reduced to measured minimum stable value (target `0.00` unless non-semantic harness noise remains).
3. No regressions in `W3C_LIMIT=83`.
4. `CURRENT_STATUS.md` and `NEXT_STEPS.md` are updated with factual progress.

## Tracking Rules

- Keep this file as the execution plan.
- Keep `CURRENT_STATUS.md` as factual state only.
- Keep `NEXT_STEPS.md` as prioritized queue with links back to this plan.
