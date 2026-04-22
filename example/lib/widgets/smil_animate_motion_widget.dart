import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

import 'animation_theme.dart';

/// Виджет с примерами SMIL animateMotion анимаций
///
/// Демонстрирует:
/// - Базовое движение по пути
/// - rotate="auto" - автоповорот по касательной
/// - rotate="auto-reverse" - автоповорот + 180°
/// - keyPoints - контроль скорости движения
/// - Сложные пути
class SMILAnimateMotionWidget extends StatefulWidget {
  const SMILAnimateMotionWidget({super.key, this.autoPlay = true});

  /// Whether to automatically start playing animations
  final bool autoPlay;

  @override
  State<SMILAnimateMotionWidget> createState() =>
      _SMILAnimateMotionWidgetState();
}

class _SMILAnimateMotionWidgetState extends State<SMILAnimateMotionWidget> {
  int _selectedExample = 0;

  final List<_MotionExample> _examples = [
    _MotionExample(
      name: 'Basic Motion',
      description: 'Simple движение по прямоугольному пути',
      svgData: '''
<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="motionPath1" d="M50,50 L250,50 L250,150 L50,150 Z" 
          fill="none" stroke="#E0E0E0" stroke-width="2" stroke-dasharray="5,5"/>
  </defs>
  
  <!-- Показываем путь -->
  <use href="#motionPath1"/>
  
  <!-- Анимированный круг -->
  <circle r="8" fill="#2196F3">
    <animateMotion
      path="M50,50 L250,50 L250,150 L50,150 Z"
      dur="4s"
      repeatCount="indefinite"/>
  </circle>
</svg>
''',
      duration: '4s',
      rotate: 'none',
    ),
    _MotionExample(
      name: 'Rotate Auto',
      description: 'Объект поворачивается по направлению движения',
      svgData: '''
<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="motionPath2" d="M50,100 C100,50 200,50 250,100 C200,150 100,150 50,100 Z" 
          fill="none" stroke="#E0E0E0" stroke-width="2" stroke-dasharray="5,5"/>
  </defs>
  
  <!-- Показываем путь -->
  <use href="#motionPath2"/>
  
  <!-- Анимированный треугольник (стрелка) -->
  <path d="M-10,-5 L10,0 L-10,5 Z" fill="#FF5722">
    <animateMotion
      path="M50,100 C100,50 200,50 250,100 C200,150 100,150 50,100 Z"
      dur="3s"
      rotate="auto"
      repeatCount="indefinite"/>
  </path>
</svg>
''',
      duration: '3s',
      rotate: 'auto',
    ),
    _MotionExample(
      name: 'Rotate Auto-Reverse',
      description: 'Автоповорот + 180° (хвост следует за головой)',
      svgData: '''
<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="motionPath3" d="M150,50 L250,150 L50,150 Z" 
          fill="none" stroke="#E0E0E0" stroke-width="2" stroke-dasharray="5,5"/>
  </defs>
  
  <!-- Показываем путь -->
  <use href="#motionPath3"/>
  
  <!-- Анимированный треугольник -->
  <path d="M-10,-5 L10,0 L-10,5 Z" fill="#9C27B0">
    <animateMotion
      path="M150,50 L250,150 L50,150 Z"
      dur="2.5s"
      rotate="auto-reverse"
      repeatCount="indefinite"/>
  </path>
</svg>
''',
      duration: '2.5s',
      rotate: 'auto-reverse',
    ),
    _MotionExample(
      name: 'With keyPoints',
      description: 'Контроль скорости движения вдоль пути',
      svgData: '''
<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="motionPath4" d="M50,100 Q150,50 250,100" 
          fill="none" stroke="#E0E0E0" stroke-width="2" stroke-dasharray="5,5"/>
  </defs>
  
  <!-- Показываем путь -->
  <use href="#motionPath4"/>
  
  <!-- Медленно движется в начале, быстро в конце -->
  <circle r="10" fill="#4CAF50">
    <animateMotion
      path="M50,100 Q150,50 250,100"
      dur="3s"
      rotate="auto"
      keyPoints="0;0.3;1"
      keyTimes="0;0.7;1"
      calcMode="linear"
      repeatCount="indefinite"/>
  </circle>
  
  <!-- Подсказка -->
  <text x="150" y="180" text-anchor="middle" font-size="12" fill="#666">
    70% времени на первые 30% пути
  </text>
</svg>
''',
      duration: '3s (keyPoints)',
      rotate: 'auto',
    ),
    _MotionExample(
      name: 'Complex Path',
      description: 'Движение по сложному пути со звездой',
      svgData: '''
<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="motionPath5" 
          d="M150,40 L165,90 L220,90 L175,120 L190,170 L150,140 L110,170 L125,120 L80,90 L135,90 Z" 
          fill="none" stroke="#E0E0E0" stroke-width="2" stroke-dasharray="5,5"/>
  </defs>
  
  <!-- Показываем путь (звезда) -->
  <use href="#motionPath5"/>
  
  <!-- Анимированный круг -->
  <g>
    <circle r="6" fill="#FF9800">
      <animateMotion
        path="M150,40 L165,90 L220,90 L175,120 L190,170 L150,140 L110,170 L125,120 L80,90 L135,90 Z"
        dur="5s"
        rotate="auto"
        repeatCount="indefinite"/>
    </circle>
  </g>
</svg>
''',
      duration: '5s',
      rotate: 'auto',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final example = _examples[_selectedExample];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AnimationTheme.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Text(
            'SMIL animateMotion',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AnimationTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AnimationTheme.spacingSmall),
          Text(
            'Демонстрация движения объектов по SVG путям с автоповоротом и keyPoints',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: AnimationTheme.spacingLarge),

          // Example selector
          SegmentedButton<int>(
            segments: _examples.asMap().entries.map((entry) {
              return ButtonSegment<int>(
                value: entry.key,
                label: Text(
                  entry.value.name,
                  key: Key('button_${entry.value.name}'),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            selected: {_selectedExample},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _selectedExample = newSelection.first;
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AnimationTheme.primaryColor;
                }
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AnimationTheme.primaryColor;
              }),
            ),
          ),
          const SizedBox(height: AnimationTheme.spacingLarge),

          // SVG Animation Preview
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AnimationTheme.radiusMedium),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AnimationTheme.radiusMedium),
              child: AnimatedSvgPicture.string(
                example.svgData,
                fit: BoxFit.contain,
                autoPlay: widget.autoPlay,
              ),
            ),
          ),
          const SizedBox(height: AnimationTheme.spacingMedium),

          // Info Panel
          Container(
            padding: const EdgeInsets.all(AnimationTheme.spacingMedium),
            decoration: BoxDecoration(
              color: AnimationTheme.primaryColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AnimationTheme.radiusMedium),
              border: Border.all(
                color: AnimationTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  example.name,
                  key: const Key('info_panel_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AnimationTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AnimationTheme.spacingSmall),
                Text(
                  example.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AnimationTheme.spacingMedium),
                Row(
                  children: [
                    _InfoChip(label: 'Duration', value: example.duration),
                    const SizedBox(width: AnimationTheme.spacingSmall),
                    _InfoChip(label: 'Rotate', value: example.rotate),
                    const SizedBox(width: AnimationTheme.spacingSmall),
                    _InfoChip(
                      label: 'Repeat',
                      value: 'indefinite',
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MotionExample {
  const _MotionExample({
    required this.name,
    required this.description,
    required this.svgData,
    required this.duration,
    required this.rotate,
  });

  final String name;
  final String description;
  final String svgData;
  final String duration;
  final String rotate;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AnimationTheme.accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: chipColor.withValues(alpha: 0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}
