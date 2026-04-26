# Resolved Issues Registry

**Last Updated:** March 13, 2026  
**Purpose:** prevent re-opening already fixed bugs and re-doing completed work.

## Closed Issues

| Issue | Status | Closed On | Evidence | Notes |
|---|---|---|---|---|
| `autoPlay: false` rendered empty frame | ✅ Closed | January 2026 | `test/animation/autoplay_false_fix_test.dart` | `autoPlay: false` now renders initial frame and works with `initialTime`. |
| `calcMode="paced"` had fallback limits for `path`/`transform` distances | ✅ Closed | March 13, 2026 | `test/animation/paced_calcmode_test.dart` | `PathDistanceCalculator` and `TransformDistanceCalculator` are covered by tests. |
| SMIL API visibility regression after `smil_animation.dart` split | ✅ Closed | March 12, 2026 | `test/animation/smil_test.dart` + parser integration tests | Public methods were restored as class members to keep API behavior stable. |

## Closed Refactor Milestones

| Milestone | Status | Closed On | Files |
|---|---|---|---|
| Split `smil_animation.dart` into smaller modules | ✅ Closed | March 12, 2026 | `smil_animation.dart`, `smil_animation_value_computation.dart`, `smil_animation_runtime.dart`, `smil_animation_curves.dart` |
| Split `smil_parser.dart` into smaller modules | ✅ Closed | March 13, 2026 | `smil_parser.dart`, `smil_parser_animation_parsing.dart`, `smil_parser_css_extraction.dart`, `smil_parser_motion.dart` |
| Split `smil_timeline.dart` into smaller modules | ✅ Closed | March 13, 2026 | `smil_timeline.dart`, `smil_timeline_runtime.dart`, `smil_timeline_syncbase.dart`, `smil_timeline_info.dart` |
| Split `css_to_smil_converter.dart` into smaller modules | ✅ Closed | March 13, 2026 | `css_to_smil_converter.dart`, `css_to_smil_converter_core.dart`, `css_to_smil_converter_timing.dart`, `css_to_smil_converter_transforms.dart` |
| Split `path_data.dart` into smaller modules | ✅ Closed | March 13, 2026 | `path_data.dart`, `path_data_base.dart`, `path_data_curves.dart` |
| Split `path_parser.dart` into smaller modules | ✅ Closed | March 13, 2026 | `path_parser.dart`, `path_parser_commands.dart`, `path_parser_scanner.dart`, `path_parser_exceptions.dart` |
| Split `path_normalizer.dart` into smaller modules | ✅ Closed | March 13, 2026 | `path_normalizer.dart`, `path_normalizer_single.dart`, `path_normalizer_alignment.dart`, `path_normalizer_curves.dart`, `path_normalizer_types.dart` |
| Split `path_interpolation.dart` into smaller modules | ✅ Closed | March 13, 2026 | `path_interpolation.dart`, `path_interpolation_helpers.dart`, `path_interpolation_morpher.dart` |
| Split `css_animations.dart` into smaller modules | ✅ Closed | March 13, 2026 | `css_animations.dart`, `css_animations_models.dart`, `css_animations_parser.dart`, `css_animations_keyframes.dart`, `css_animations_timing.dart` |
| Split `svg_parser_filters_primitives.dart` into smaller modules | ✅ Closed | March 13, 2026 | `svg_parser_filters_primitives.dart`, `svg_parser_filters_primitives_advanced.dart` |
| Split `svg_filters_registry_pipeline.dart` into smaller modules | ✅ Closed | March 13, 2026 | `svg_filters_registry_pipeline.dart`, `svg_filters_registry_pipeline_primitives.dart`, `svg_filters_registry_pipeline_compositing.dart` |
| Further split `svg_filters_registry_pipeline_primitives.dart` into smaller modules | ✅ Closed | March 13, 2026 | `svg_filters_registry_pipeline_primitives.dart`, `svg_filters_registry_pipeline_primitives_effects.dart`, `svg_filters_registry_pipeline_primitives_paint.dart` |
| Split `animated_svg_painter.dart` tree/filter traversal into smaller modules | ✅ Closed | March 13, 2026 | `animated_svg_painter.dart`, `animated_svg_painter_tree.dart` |
| Split `animated_svg_painter_gradients.dart` into smaller modules | ✅ Closed | March 13, 2026 | `animated_svg_painter_gradients.dart`, `animated_svg_painter_gradients_resolver.dart`, `animated_svg_painter_gradients_values.dart` |
| Split `animated_svg_painter_clip_mask.dart` into smaller modules | ✅ Closed | March 13, 2026 | `animated_svg_painter_clip_mask.dart`, `animated_svg_painter_clip_mask_geometry.dart`, `animated_svg_painter_clip_mask_units.dart` |
| Split `smil/interpolators.dart` into smaller modules | ✅ Closed | March 13, 2026 | `interpolators.dart`, `interpolators_path.dart`, `interpolators_transform.dart`, `interpolators_color_parsing.dart` |
| Further split `css_to_smil_converter_transforms.dart` into smaller modules | ✅ Closed | March 13, 2026 | `css_to_smil_converter_transforms.dart`, `css_to_smil_converter_transforms_decompose.dart`, `css_to_smil_converter_transforms_decompose_timing.dart`, `css_to_smil_converter_transforms_values.dart` |

## Re-open Policy

Re-open a closed issue only when:
1. a failing regression test demonstrates a real breakage,
2. the breakage reproduces on current `main`,
3. a new test is added before the fix.

## Validation Baseline (Latest)

Run in project root:

```bash
.fvm/versions/3.38.1/bin/flutter test
.fvm/versions/3.38.1/bin/dart analyze lib/ test/
```

Latest run (March 27, 2026):
- `flutter test`: **3,413+ tests passed**
- `dart analyze`: **0 errors**, **0 warnings**, 1 info
