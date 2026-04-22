import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation.dart';
import '../state/app_state.dart';

/// Виджет для отображения AnimatedSvgPicture с текущими параметрами из AppState
class AnimatedSvgViewer extends StatelessWidget {
  final String svgContent;
  final AppState state;
  final String? exampleId;

  const AnimatedSvgViewer({
    super.key,
    required this.svgContent,
    required this.state,
    this.exampleId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: state.backgroundColor,
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: AnimatedSvgPicture.string(
          svgContent,
          // CRITICAL: Key prevents recreating AnimationController on state changes
          key: exampleId != null
              ? ValueKey(exampleId)
              : ValueKey(svgContent.hashCode),
          width: state.width,
          height: state.height,
          fit: state.fit,
          alignment: state.alignment,
          backgroundColor: state.backgroundColor,
          playbackRate: state.playbackRate,
          autoPlay: state.autoPlay,
          initialTime: state.initialTime,
        ),
      ),
    );
  }
}
