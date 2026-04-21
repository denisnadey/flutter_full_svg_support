# Release Checklist

**Last Updated:** April 21, 2026  
**Scope:** Public release readiness for `flutter_svg`

## Release Gate Rule

Release is allowed only when all gates below are green.

## Baseline Snapshot (Captured April 21, 2026)

Commands run from `/Users/denisnadey/apps/flutter_full_svg_support`:

```bash
.fvm/versions/3.38.1/bin/dart analyze lib/ test/ example/lib/
.fvm/versions/3.38.1/bin/flutter test
RUN_W3C_STATIC=1 W3C_LIMIT=83 .fvm/versions/3.38.1/bin/flutter test test/w3c/w3c_static_golden_test.dart
```

Current baseline:

- Analyzer: `3` warnings (not release-ready).
- Full test suite: failed (`-16`).
- W3C static (`W3C_LIMIT=83`): failed (`33` fixture failures; masking/painting/paths clusters).

Open analyzer warnings:

1. `lib/src/animation/animated_svg_painter_gradients_values.dart:95` - `_resolveColorValue` unused.
2. `lib/src/animation/svg_filters_primitives_turbulence.dart:97` - `_gradients` field unused.
3. `lib/src/animation/svg_filters_primitives_turbulence.dart:484` - `_fade` unused.

## Gate A - Code Health

- [ ] `dart analyze lib/ test/ example/lib/` returns zero errors and zero warnings.
- [ ] `flutter test` returns all green on target platforms.
- [ ] Golden/widget failures are either fixed or intentionally re-baselined with explicit approval.

## Gate B - W3C Functional Readiness

- [ ] Execute waves from `docs/W3C_GAP_CLOSURE_PLAN.md`.
- [ ] Close highest-delta fixtures first (`masking-path-03-b`, `painting-stroke-02-t`, `painting-stroke-03-t`, `painting-fill-02-t`, `painting-stroke-04-t`, `painting-render-02-b`).
- [ ] Keep threshold reductions measured (`tool/w3c_suite/tune_threshold_case.sh`), no blind tuning.
- [ ] Re-run `W3C_LIMIT=83` until target slice is stable.

## Gate C - Documentation Consistency

- [ ] Sync factual metrics across `README.md`, `CURRENT_STATUS.md`, `NEXT_STEPS.md`, `docs/README.md`.
- [ ] Keep W3C tactical plan in `docs/W3C_GAP_CLOSURE_PLAN.md`.
- [ ] Update `CHANGELOG.md` (`NEXT` section) with only verified release content.

## Gate D - Packaging and Publish Readiness

- [ ] Decide release channel (`beta` vs `stable`) and target version.
- [ ] Remove `publish_to: 'none'` in `pubspec.yaml` when publishing is approved.
- [ ] Run publish dry-run:

```bash
.fvm/versions/3.38.1/bin/dart pub publish --dry-run
```

- [ ] Resolve all dry-run blockers (if any).

## Gate E - Release Operations

- [ ] Create release branch and freeze scope.
- [ ] Cut release notes from validated changes only.
- [ ] Tag release and publish.
- [ ] Post-release smoke test on supported platforms.

## Working Order (Execution)

1. Gate A (analyze/tests) until green.
2. Gate B (W3C closure waves).
3. Gate C (docs sync).
4. Gate D (dry-run and metadata validation).
5. Gate E (branch/tag/publish).
