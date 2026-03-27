# Development Roadmap - Visual Overview (Living)

```mermaid
gantt
    title Flutter SVG Animated Pipeline Roadmap (Current)
    dateFormat  YYYY-MM-DD

    section Closed
    autoPlay false rendering fix               :done, c1, 2026-01-10, 2d
    paced path/transform distance support      :done, c2, 2026-03-13, 1d
    smil_animation modular split               :done, c3, 2026-03-12, 1d
    smil_parser modular split                  :done, c4, 2026-03-13, 1d
    smil_timeline modular split                :done, c5, 2026-03-13, 1d
    css_to_smil_converter modular split        :done, c6, 2026-03-13, 1d

    section Active Priorities
    Advanced filter graph semantics            :active, p1, 2026-03-14, 21d
    Advanced text parity (~90% done)             :done, p2, 2026-03-14, 14d
    Text remaining edge cases                     :p2b, after p2, 7d
    Advanced hit-testing parity                :p3, after p2, 21d
    Advanced use/symbol inheritance parity     :p4, after p3, 14d

    section Quality
    CSS/SMIL regression fixture expansion      :q1, after p1, 14d
    Analyzer deprecation cleanup (incremental) :q2, after p1, 30d
```

## Status Legend

- `Closed`: completed and regression-covered.
- `Active Priorities`: current delivery queue.
- `Quality`: ongoing hardening tasks.

## Source of Truth

- [CURRENT_STATUS.md](CURRENT_STATUS.md)
- [TODO.md](TODO.md)
- [NEXT_STEPS.md](NEXT_STEPS.md)
- [docs/RESOLVED_ISSUES.md](docs/RESOLVED_ISSUES.md)
