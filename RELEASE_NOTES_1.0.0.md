# full_svg_flutter 1.0.0 Release Notes

**Release Track:** stable  
**Date Prepared:** April 22, 2026

## Summary

This release starts a new publication line under the package name `full_svg_flutter`.

## Validated Release Content

- Package identity reset to:
  - `name: full_svg_flutter`
  - `version: 1.0.0`
  - canonical import path `package:full_svg_flutter/full_svg_flutter.dart`
- Internal imports and local/example dependencies migrated from `flutter_svg` to `full_svg_flutter`.
- W3C static 83-slice remains green (`83/83`).
- Analyzer and full test suite remain green.
- Publish readiness hardening:
  - direct `meta` dependency declared
  - `publish_to: 'none'` removed
  - `.pubignore` added to reduce published payload and exclude development-only assets
  - documentation path normalized from `docs/` to `doc/`
- `dart pub publish --dry-run` passes with `0` warnings on clean git state.

## Verification Snapshot

- `dart analyze lib/ test/ example/lib/` -> 0 errors, 0 warnings
- `flutter test` -> all tests passed (`4,922` pass / `2` skipped)
- `RUN_W3C_STATIC=1 W3C_LIMIT=83 flutter test test/w3c/w3c_static_golden_test.dart` -> `83` pass / `0` fail
- `dart pub publish --dry-run` -> `0` warnings (clean state)

## Publication Checklist

- [x] Gate A complete
- [x] Gate B complete
- [x] Gate C complete
- [x] Gate D complete
- [ ] Tag release and publish to pub.dev
- [ ] Post-release smoke test
