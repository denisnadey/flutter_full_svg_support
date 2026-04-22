# Release Checklist

**Last Updated:** April 22, 2026  
**Scope:** Public release readiness for `full_svg_flutter`

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

- Analyzer: green (`0` errors, `0` warnings) after cleanup on April 21, 2026.
- Full test suite: passed (`4,922` pass / `2` skipped).
- W3C static (`W3C_LIMIT=83`): passed (`83` pass / `0` fail), re-verified on April 22, 2026.

## Gate A - Code Health

- [x] `dart analyze lib/ test/ example/lib/` returns zero errors and zero warnings.
- [x] `flutter test` returns all green on target platforms.
- [x] Golden/widget failures are either fixed or intentionally re-baselined with explicit approval.

## Gate B - W3C Functional Readiness

- [x] Execute waves from `doc/W3C_GAP_CLOSURE_PLAN.md`.
- [x] Close highest-delta fixtures first (`masking-path-03-b`, `painting-stroke-02-t`, `painting-stroke-03-t`, `painting-fill-02-t`, `painting-stroke-04-t`, `painting-render-02-b`).
- [x] Keep threshold reductions measured (`tool/w3c_suite/tune_threshold_case.sh`), no blind tuning.
- [x] Re-run `W3C_LIMIT=83` until target slice is stable.

## Gate C - Documentation Consistency

- [x] Sync factual metrics across `README.md`, `CURRENT_STATUS.md`, `NEXT_STEPS.md`, `doc/README.md`.
- [x] Keep W3C tactical plan in `doc/W3C_GAP_CLOSURE_PLAN.md`.
- [x] Update `CHANGELOG.md` (`NEXT` section) with only verified release content.

## Gate D - Packaging and Publish Readiness

- [x] Decide release channel (`beta` vs `stable`) and target version (`stable 1.0.0`).
- [x] Remove `publish_to: 'none'` in `pubspec.yaml` when publishing is approved.
- [x] Run publish dry-run:

```bash
.fvm/versions/3.38.1/bin/dart pub publish --dry-run
```

- Dry-run executed on April 22, 2026 for `full_svg_flutter` `1.0.0`; `meta` dependency blocker is fixed.
- [x] Resolve all dry-run blockers (if any).
  - Dry-run re-run on clean git state with `0` warnings (April 22, 2026).
  - Gitignored-but-checked-in warning removed by untracking `.dart_tool/*`, `.vscode/settings.json`, and lockfiles; publish payload constrained via `.pubignore`.

## Gate E - Release Operations

- [x] Create release branch and freeze scope (`codex/release-full-svg-flutter-1-0-0`).
- [x] Cut release notes from validated changes only (`RELEASE_NOTES_1.0.0.md`).
- [ ] Tag release and publish.
- [ ] Post-release smoke test on supported platforms.

## Working Order (Execution)

1. Gate A (analyze/tests) until green.
2. Gate B (W3C closure waves).
3. Gate C (docs sync).
4. Gate D (dry-run and metadata validation).
5. Gate E (branch/tag/publish).
