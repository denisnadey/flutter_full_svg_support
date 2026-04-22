import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

import 'animation_theme.dart';

/// Виджет с примерами SMIL syncbase timing
///
/// Демонстрирует:
/// - begin="anim1.begin" - синхронизация с началом анимации
/// - begin="anim1.end" - начало после завершения анимации
/// - begin="anim1.end+2s" - начало с задержкой после завершения
/// - begin="anim1.repeat(2)" - начало на определенном повторе
/// - Цепочки зависимостей
class SMILSyncbaseWidget extends StatefulWidget {
  const SMILSyncbaseWidget({super.key, this.autoPlay = true});

  /// Whether to automatically start playing animations
  final bool autoPlay;

  @override
  State<SMILSyncbaseWidget> createState() => _SMILSyncbaseWidgetState();
}

class _SMILSyncbaseWidgetState extends State<SMILSyncbaseWidget> {
  int _selectedExample = 0;

  final List<_SyncbaseExample> _examples = [
    _SyncbaseExample(
      name: 'Simple Begin Sync',
      description: 'Второй элемент начинает анимацию одновременно с первым',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Первая анимация -->
  <circle cx="50" cy="100" r="20" fill="#2196F3">
    <animate id="anim1"
      attributeName="cx"
      from="50" to="350"
      dur="3s"
      repeatCount="indefinite"/>
  </circle>
  
  <!-- Вторая анимация синхронизирована с первой -->
  <circle cx="50" cy="150" r="15" fill="#FF5722">
    <animate
      attributeName="cx"
      from="50" to="350"
      begin="anim1.begin"
      dur="3s"
      repeatCount="indefinite"/>
  </circle>
  
  <!-- Метки -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Обе анимации начинаются одновременно
  </text>
</svg>
''',
      timing: 'begin="anim1.begin"',
      type: 'begin sync',
    ),
    _SyncbaseExample(
      name: 'End Sync',
      description: 'Вторая анимация начинается когда первая заканчивается',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Первая анимация - 2 секунды -->
  <rect x="20" y="80" width="40" height="40" fill="#4CAF50">
    <animate id="rect1"
      attributeName="x"
      from="20" to="160"
      dur="2s"
      repeatCount="1"
      fill="freeze"/>
  </rect>
  
  <!-- Вторая анимация начинается когда первая заканчивается -->
  <rect x="200" y="80" width="40" height="40" fill="#9C27B0">
    <animate
      attributeName="x"
      from="200" to="340"
      begin="rect1.end"
      dur="2s"
      repeatCount="1"
      fill="freeze"/>
  </rect>
  
  <!-- Метки -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Вторая начинается после первой
  </text>
  <text x="90" y="160" text-anchor="middle" font-size="12" fill="#4CAF50">0-2s</text>
  <text x="270" y="160" text-anchor="middle" font-size="12" fill="#9C27B0">2-4s</text>
</svg>
''',
      timing: 'begin="rect1.end"',
      type: 'end sync',
    ),
    _SyncbaseExample(
      name: 'End Sync with Offset',
      description:
          'Вторая анимация начинается через 1 секунду после завершения первой',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Первая анимация - пульсация -->
  <circle cx="100" cy="100" r="20" fill="#2196F3">
    <animate id="pulse1"
      attributeName="r"
      from="20" to="40"
      dur="1.5s"
      repeatCount="1"
      fill="freeze"/>
  </circle>
  
  <!-- Вторая анимация начинается через 1s после первой -->
  <circle cx="250" cy="100" r="20" fill="#FF5722">
    <animate
      attributeName="r"
      from="20" to="40"
      begin="pulse1.end+1s"
      dur="1.5s"
      repeatCount="1"
      fill="freeze"/>
  </circle>
  
  <!-- Метки -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    1 секунда паузы между анимациями
  </text>
  <text x="100" y="170" text-anchor="middle" font-size="12" fill="#2196F3">0-1.5s</text>
  <text x="250" y="170" text-anchor="middle" font-size="12" fill="#FF5722">2.5-4s</text>
</svg>
''',
      timing: 'begin="pulse1.end+1s"',
      type: 'end + offset',
    ),
    _SyncbaseExample(
      name: 'Repeat Sync',
      description: 'Анимация начинается на втором повторе другой анимации',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Первая анимация - 3 повтора по 1s -->
  <rect x="20" y="60" width="30" height="30" fill="#4CAF50">
    <animate id="bounce"
      attributeName="y"
      values="60;40;60"
      dur="1s"
      repeatCount="3"
      fill="freeze"/>
  </rect>
  
  <!-- Вторая анимация начинается на 2-м повторе первой (t=1s) -->
  <circle cx="200" cy="100" r="15" fill="#FF9800">
    <animate
      attributeName="r"
      from="15" to="30"
      begin="bounce.repeat(1)"
      dur="2s"
      repeatCount="1"
      fill="freeze"/>
  </circle>
  
  <!-- Метки -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Круг растет на 2-м повторе прыжка
  </text>
  <text x="35" y="140" text-anchor="middle" font-size="10" fill="#4CAF50">прыжок x3</text>
  <text x="200" y="165" text-anchor="middle" font-size="10" fill="#FF9800">начало на 2-м повторе</text>
</svg>
''',
      timing: 'begin="bounce.repeat(1)"',
      type: 'repeat sync',
    ),
    _SyncbaseExample(
      name: 'Chained Dependencies',
      description: 'Цепочка из трех последовательных анимаций',
      svgData: '''
<svg viewBox="0 0 400 250" xmlns="http://www.w3.org/2000/svg">
  <!-- Первая анимация -->
  <circle cx="50" cy="80" r="20" fill="#2196F3">
    <animate id="chain1"
      attributeName="cx"
      from="50" to="150"
      dur="1.5s"
      repeatCount="1"
      fill="freeze"/>
  </circle>
  
  <!-- Вторая начинается когда первая заканчивается -->
  <circle cx="50" cy="130" r="20" fill="#4CAF50">
    <animate id="chain2"
      attributeName="cx"
      from="50" to="150"
      begin="chain1.end"
      dur="1.5s"
      repeatCount="1"
      fill="freeze"/>
  </circle>
  
  <!-- Третья начинается когда вторая заканчивается -->
  <circle cx="50" cy="180" r="20" fill="#FF5722">
    <animate
      attributeName="cx"
      from="50" to="150"
      begin="chain2.end"
      dur="1.5s"
      repeatCount="1"
      fill="freeze"/>
  </circle>
  
  <!-- Метки -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Последовательная цепочка
  </text>
  <text x="100" y="60" font-size="11" fill="#2196F3">1: 0-1.5s</text>
  <text x="100" y="110" font-size="11" fill="#4CAF50">2: 1.5-3s</text>
  <text x="100" y="160" font-size="11" fill="#FF5722">3: 3-4.5s</text>
</svg>
''',
      timing: 'chain: end→end→end',
      type: 'chained',
    ),
    _SyncbaseExample(
      name: 'Parallel + Sequential',
      description: 'Комбинация параллельных и последовательных анимаций',
      svgData: '''
<svg viewBox="0 0 400 250" xmlns="http://www.w3.org/2000/svg">
  <!-- Первая группа - параллельно -->
  <rect x="20" y="70" width="30" height="30" fill="#2196F3">
    <animate id="para1"
      attributeName="x"
      from="20" to="150"
      dur="2s"
      repeatCount="1"
      fill="freeze"/>
  </rect>
  
  <rect x="20" y="110" width="30" height="30" fill="#2196F3" opacity="0.6">
    <animate
      attributeName="x"
      from="20" to="150"
      begin="para1.begin"
      dur="2s"
      repeatCount="1"
      fill="freeze"/>
  </rect>
  
  <!-- Вторая группа - после первой -->
  <circle cx="220" cy="85" r="15" fill="#4CAF50">
    <animate id="seq1"
      attributeName="cx"
      from="220" to="350"
      begin="para1.end"
      dur="2s"
      repeatCount="1"
      fill="freeze"/>
  </circle>
  
  <circle cx="220" cy="125" r="15" fill="#4CAF50" opacity="0.6">
    <animate
      attributeName="cx"
      from="220" to="350"
      begin="seq1.begin"
      dur="2s"
      repeatCount="1"
      fill="freeze"/>
  </circle>
  
  <!-- Метки -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Параллельные группы последовательно
  </text>
  <text x="85" y="160" text-anchor="middle" font-size="11" fill="#2196F3">Группа 1</text>
  <text x="285" y="160" text-anchor="middle" font-size="11" fill="#4CAF50">Группа 2</text>
</svg>
''',
      timing: 'mixed sync',
      type: 'complex',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final example = _examples[_selectedExample];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Информационная панель
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AnimationTheme.spacingMedium),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                example.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AnimationTheme.spacingSmall),
              Text(
                example.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: AnimationTheme.spacingMedium),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[850]
                      : AnimationTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AnimationTheme.radiusSmall,
                  ),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync,
                      size: 16,
                      color: AnimationTheme.accentColor,
                    ),
                    const SizedBox(width: AnimationTheme.spacingSmall),
                    Text(
                      example.timing,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: AnimationTheme.spacingMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AnimationTheme.accentColor.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        example.type,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AnimationTheme.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Селектор примера
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AnimationTheme.spacingMedium,
            vertical: AnimationTheme.spacingSmall,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_examples.length, (index) {
              final isSelected = index == _selectedExample;
              return Material(
                color: isSelected
                    ? AnimationTheme.accentColor
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AnimationTheme.radiusSmall),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedExample = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(
                    AnimationTheme.radiusSmall,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      _examples[index].name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // SVG Canvas
        Expanded(
          child: Container(
            color: AnimationTheme.backgroundColor,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(AnimationTheme.spacingLarge),
                child: AnimatedSvgPicture.string(
                  example.svgData,
                  fit: BoxFit.contain,
                  autoPlay: widget.autoPlay,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Модель примера syncbase анимации
class _SyncbaseExample {
  const _SyncbaseExample({
    required this.name,
    required this.description,
    required this.svgData,
    required this.timing,
    required this.type,
  });

  final String name;
  final String description;
  final String svgData;
  final String timing;
  final String type;
}
