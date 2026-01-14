# flutter_svg Documentation

Organized documentation for package users and contributors.

## 📚 For Package Users

Start here if you're using flutter_svg in your app:

- **[README.md](../README.md)** - Package overview, installation, basic usage
- **[ANIMATION.md](../ANIMATION.md)** - SMIL animation guide with examples
- **[CHANGELOG.md](../CHANGELOG.md)** - Version history and breaking changes

## 🛠️ For Contributors

Development guides and technical documentation:

- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Complete development workflow, testing, architecture
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** - Dual pipeline design rationale
- **[VISUAL_TESTING_GUIDELINES.md](../VISUAL_TESTING_GUIDELINES.md)** - Visual testing patterns
- **[CURRENT_STATUS.md](../CURRENT_STATUS.md)** - Latest development status

## 🤖 For AI Coding Agents

Optimized instructions for GitHub Copilot and other AI tools:

- **[.github/copilot-instructions.md](../.github/copilot-instructions.md)** - Comprehensive AI agent guide
  - Project architecture and why it's designed this way
  - Test-first workflow (313 tests, all passing)
  - Visual testing requirements and gotchas
  - Code locations and organization
  - Common patterns for adding features
  - Critical development pitfalls

## 📦 Archive

Historical implementation documents (Stages 1-6):

- **[archive/](archive/)** - Detailed stage reports and original architectural plan
  - `ANIMATION_ARCHITECTURE.md` - Original 11-stage plan
  - `STAGE_5_*.md` - Transform animations implementation
  - `STAGE_6_*.md` - Path animations & motion implementation
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

**Run the example app**
```bash
cd example && flutter run
```

**Run tests**
```bash
flutter test test/animation/
```

## Documentation Structure

```
flutter_svg/
├── README.md                          # Package overview
├── ANIMATION.md                       # User guide (SMIL)
├── ARCHITECTURE.md                    # Design rationale
├── CURRENT_STATUS.md                  # Latest status
├── VISUAL_TESTING_GUIDELINES.md       # Testing patterns
├── CHANGELOG.md                       # Version history
│
├── .github/
│   └── copilot-instructions.md        # AI agent guide
│
└── docs/
    ├── README.md                      # This file
    ├── DEVELOPMENT.md                 # Complete dev guide
    └── archive/                       # Historical docs
        ├── README.md
        ├── ANIMATION_ARCHITECTURE.md
        ├── STAGE_5_*.md
        └── STAGE_6_*.md
```

## Contributing

1. Read [DEVELOPMENT.md](DEVELOPMENT.md)
2. Run tests: `flutter test test/animation/`
3. Check [CURRENT_STATUS.md](../CURRENT_STATUS.md) for roadmap
4. Submit PR with tests

## Questions?

- **General usage**: See examples in [ANIMATION.md](../ANIMATION.md)
- **Development setup**: [DEVELOPMENT.md](DEVELOPMENT.md)
- **Architecture questions**: [ARCHITECTURE.md](../ARCHITECTURE.md)
- **Testing issues**: [VISUAL_TESTING_GUIDELINES.md](../VISUAL_TESTING_GUIDELINES.md)
