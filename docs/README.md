# flutter_svg Documentation

Organized documentation for package users and contributors.

**Last Updated:** April 21, 2026

**Current State:** Release gate baseline (April 21, 2026): analyzer green, full `flutter test` passing (`4,922` pass / `2` skipped), W3C 83-slice passing (`83/83`).

## Release Baseline (April 21, 2026)

- `dart analyze lib/ test/ example/lib/` -> 0 errors, 0 warnings
- `.fvm/versions/3.38.1/bin/flutter test` -> all tests passed (`4,922` pass / `2` skipped)
- `RUN_W3C_STATIC=1 W3C_LIMIT=83 .fvm/versions/3.38.1/bin/flutter test test/w3c/w3c_static_golden_test.dart` -> 83 pass / 0 fail

## Historical Parity Overview (March 2026 Snapshot)

The animated pipeline (`AnimatedSvgPicture`) implements a custom DOM-based renderer with:
- **Strongest areas** (~85-95%): Geometry (all 8 shapes + paint servers), SMIL animation (5 elements, full timing), CSS interop (selectors, cascade, variables, 3D transforms)
- **Solid coverage** (~70-80%): Interaction/events, accessibility, structural elements, text/typography, clipping/masking
- **Active gaps** (~60-68%): Filter effects (17/25 primitives, advanced graph semantics pending), external content

Historical note (March 2026 snapshot): **7 P0 priorities remained** at that time (advanced filter graph, typography edge cases, complex clipping/masking, use/symbol inheritance, light sources, component transfer functions).

For the full gap matrix see [BLINK_PARITY_AUDIT.md](BLINK_PARITY_AUDIT.md).

## 📚 For Package Users

- **[README.md](../README.md)** - Package overview, parity snapshot, installation, usage
- **[ANIMATION.md](../ANIMATION.md)** - SMIL & CSS animation guide with code examples
- **[CHANGELOG.md](../CHANGELOG.md)** - Version history and breaking changes

## 🛠️ For Contributors

- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Workflow, commands, conventions
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** - Dual pipeline design (static vs animated)
- **[VISUAL_TESTING_GUIDELINES.md](../VISUAL_TESTING_GUIDELINES.md)** - Visual testing patterns
- **[CURRENT_STATUS.md](../CURRENT_STATUS.md)** - Single source of truth for project state
- **[BLINK_PARITY_AUDIT.md](BLINK_PARITY_AUDIT.md)** - Gap matrix vs Blink (81 tags baseline, 25 FE primitives)
- **[W3C_GAP_CLOSURE_PLAN.md](W3C_GAP_CLOSURE_PLAN.md)** - Active Chromium-driven W3C closure plan with priority waves and threshold policy
- **[RELEASE_CHECKLIST.md](../RELEASE_CHECKLIST.md)** - Release gates, baseline, and publication blockers
- **[RESOLVED_ISSUES.md](RESOLVED_ISSUES.md)** - Closed bugs/milestones (do-not-reopen registry)
- **[DOCUMENTATION_INDEX.md](../DOCUMENTATION_INDEX.md)** - Central navigation hub

## 🤖 For AI Coding Agents

Optimized instructions for GitHub Copilot and other AI tools:

- **[.github/copilot-instructions.md](../.github/copilot-instructions.md)** - Comprehensive AI agent guide
  - Project architecture and why it's designed this way
  - Test-first workflow
  - Visual testing requirements and gotchas
  - Code locations and organization
  - Common patterns for adding features
  - Critical development pitfalls

## 📦 Archive

Historical implementation documents (Stages 1-8):

- **[archive/](archive/)** - Detailed stage reports and original architectural plan
  - `ANIMATION_ARCHITECTURE.md` - Original 11-stage plan
  - `STAGE_*.md` - Stage completion reports
  - `SESSION_*.md` - Development session logs
  - See [archive/README.md](archive/README.md) for full index

## Quick Navigation

### I want to...

**Use animations in my app**
→ [ANIMATION.md](../ANIMATION.md)

**Understand the architecture**
→ [ARCHITECTURE.md](../ARCHITECTURE.md)

**Contribute code**
→ [DEVELOPMENT.md](DEVELOPMENT.md)

**Write tests**
→ [VISUAL_TESTING_GUIDELINES.md](../VISUAL_TESTING_GUIDELINES.md)

**See what's implemented**
→ [CURRENT_STATUS.md](../CURRENT_STATUS.md)

**Check what is already fixed (do-not-reopen list)**
→ [RESOLVED_ISSUES.md](RESOLVED_ISSUES.md)

**See what is still missing vs Blink**
→ [BLINK_PARITY_AUDIT.md](BLINK_PARITY_AUDIT.md) (81 tags, 25 FE primitives baseline)

**See what's next**
→ [NEXT_STEPS.md](../NEXT_STEPS.md) (release-gate queue + Wave A/B/C execution order)

**Close W3C gaps fast**
→ [W3C_GAP_CLOSURE_PLAN.md](W3C_GAP_CLOSURE_PLAN.md) (Chromium-guided functional closure + measured threshold reduction)

**Check release readiness**
→ [RELEASE_CHECKLIST.md](../RELEASE_CHECKLIST.md)

**Run the example app**
```bash
cd example && ../.fvm/flutter_sdk/bin/flutter run
```

**Run tests**
```bash
./.fvm/flutter_sdk/bin/flutter test
```

## Documentation Structure

```
flutter_svg/
├── README.md                          # Package overview + release baseline
├── ANIMATION.md                       # User guide (SMIL & CSS)
├── ARCHITECTURE.md                    # Dual pipeline design rationale
├── CURRENT_STATUS.md                  # Single source of truth for project state
├── TODO.md                            # Active work queue
├── NEXT_STEPS.md                      # Execution order (P0 priorities)
├── RELEASE_CHECKLIST.md               # Release readiness gates
├── ROADMAP.md                         # Living roadmap with milestones
├── DOCUMENTATION_INDEX.md             # Central navigation hub
├── VISUAL_TESTING_GUIDELINES.md       # Testing patterns
├── CHANGELOG.md                       # Version history
│
├── .github/
│   └── copilot-instructions.md        # AI agent guide
│
└── docs/
    ├── README.md                      # This file
    ├── DEVELOPMENT.md                 # Complete dev guide
    ├── BLINK_PARITY_AUDIT.md          # Blink gap matrix
    ├── W3C_GAP_CLOSURE_PLAN.md        # Active W3C closure execution plan
    ├── RESOLVED_ISSUES.md             # Closed issues / do-not-reopen registry
    └── archive/                       # Historical docs (Stages 1-8)
```

## Contributing

1. Read [DEVELOPMENT.md](DEVELOPMENT.md)
2. Run tests: `./.fvm/flutter_sdk/bin/flutter test`
3. Run analyzer: `./.fvm/flutter_sdk/bin/flutter analyze`
4. Check [CURRENT_STATUS.md](../CURRENT_STATUS.md) for factual state
5. Check [RESOLVED_ISSUES.md](RESOLVED_ISSUES.md) to avoid reopening closed bug classes
6. Submit PR with tests

## Questions?

- **General usage**: See examples in [ANIMATION.md](../ANIMATION.md)
- **Development setup**: [DEVELOPMENT.md](DEVELOPMENT.md)
- **Architecture questions**: [ARCHITECTURE.md](../ARCHITECTURE.md)
- **Testing issues**: [VISUAL_TESTING_GUIDELINES.md](../VISUAL_TESTING_GUIDELINES.md)
