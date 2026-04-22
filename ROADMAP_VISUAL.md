# Development Roadmap - Visual Overview (Living)

```mermaid
gantt
    title Flutter SVG Animated Pipeline Roadmap (Current)
    dateFormat  YYYY-MM-DD

    section Closed
    autoPlay false rendering fix               :done, c1, 2026-01-10, 2d
    paced path/transform distance support      :done, c2, 2026-03-13, 1d
    Modular code splits (18 milestones)        :done, c3, 2026-03-12, 2d
    Text & Typography (~99% parity)            :done, c4, 2026-03-14, 14d

    section Active Priorities (P0)
    Advanced filter graph semantics            :active, p1, 2026-03-28, 21d
    Advanced clipping compositions             :p2, after p1, 14d
    Advanced masking (luminance/alpha)         :p3, after p1, 14d
    use/symbol inheritance edge cases          :p4, after p2, 14d
    Light sources advanced positioning         :p5, after p3, 14d
    Component transfer functions               :p6, after p4, 7d

    section Quality
    CSS/SMIL regression fixture expansion      :q1, after p1, 14d
    Analyzer info-level cleanup                :q2, after p1, 30d
```

## Status Legend

- `Closed`: completed and regression-covered.
- `Active Priorities (P0)`: current delivery queue.
- `Quality`: ongoing hardening tasks.

## Source of Truth

- [CURRENT_STATUS.md](CURRENT_STATUS.md)
- [TODO.md](TODO.md)
- [NEXT_STEPS.md](NEXT_STEPS.md)
- [doc/RESOLVED_ISSUES.md](doc/RESOLVED_ISSUES.md)
