import 'package:flutter/material.dart';
import 'package:full_svg_flutter/src/animation/animated_svg_picture.dart';

/// Виджет с примерами SMIL event-based timing
///
/// Демонстрирует:
/// - begin="click" - начало анимации по клику
/// - begin="mouseover" - начало по наведению мыши
/// - begin="click+1s" - начало с задержкой после клика
/// - Цепочки событий
class SMILEventTimingWidget extends StatefulWidget {
  const SMILEventTimingWidget({super.key, this.autoPlay = false});

  /// Whether to automatically start playing animations (usually false for event-based)
  final bool autoPlay;

  @override
  State<SMILEventTimingWidget> createState() => _SMILEventTimingWidgetState();
}

class _SMILEventTimingWidgetState extends State<SMILEventTimingWidget> {
  int _selectedExample = 0;

  final List<_EventExample> _examples = [
    _EventExample(
      name: 'Click to Start',
      description: 'Кликните на область, чтобы запустить анимацию',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Фон для клика -->
  <rect x="0" y="0" width="400" height="200" fill="#f0f0f0" opacity="0"/>
  
  <!-- Квадрат, который анимируется по клику -->
  <rect x="50" y="80" width="40" height="40" fill="#2196F3">
    <animate
      attributeName="x"
      from="50" to="310"
      dur="2s"
      begin="click"
      fill="freeze"/>
  </rect>
  
  <!-- Подсказка -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Нажмите на SVG, чтобы запустить анимацию
  </text>
  
  <!-- Индикатор -->
  <circle cx="200" cy="170" r="5" fill="#FF5722">
    <animate
      attributeName="fill"
      values="#FF5722; #4CAF50; #FF5722"
      dur="0.5s"
      begin="click"
      fill="freeze"/>
  </circle>
</svg>
''',
      timing: 'begin="click"',
      eventType: 'click',
    ),
    _EventExample(
      name: 'Hover Effect',
      description: 'Наведите курсор мыши для запуска анимации',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Фон для hover -->
  <rect x="0" y="0" width="400" height="200" fill="#e8f5e9" opacity="0.3"/>
  
  <!-- Круг, который пульсирует при наведении -->
  <circle cx="200" cy="100" r="30" fill="#4CAF50">
    <animate
      attributeName="r"
      from="30" to="50"
      dur="1s"
      begin="mouseover"
      fill="freeze"/>
    <animate
      attributeName="fill"
      from="#4CAF50" to="#8BC34A"
      dur="1s"
      begin="mouseover"
      fill="freeze"/>
  </circle>
  
  <!-- Подсказка -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#2E7D32">
    Наведите курсор на SVG
  </text>
  
  <!-- Дополнительная анимация при выходе -->
  <circle cx="200" cy="100" r="30" fill="none" stroke="#4CAF50" stroke-width="2">
    <animate
      attributeName="r"
      from="50" to="30"
      dur="1s"
      begin="mouseout"
      fill="freeze"/>
  </circle>
</svg>
''',
      timing: 'begin="mouseover"',
      eventType: 'hover',
    ),
    _EventExample(
      name: 'Delayed Start',
      description: 'Анимация начинается через 1 секунду после клика',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Кнопка -->
  <rect x="150" y="80" width="100" height="40" rx="20" fill="#9C27B0"/>
  <text x="200" y="107" text-anchor="middle" font-size="16" fill="white">Кликни</text>
  
  <!-- Индикатор задержки -->
  <circle cx="80" cy="100" r="15" fill="#FFB300" opacity="0.3">
    <animate
      attributeName="opacity"
      from="0.3" to="1"
      dur="1s"
      begin="click"
      fill="freeze"/>
  </circle>
  
  <!-- Основная анимация с задержкой -->
  <rect x="280" y="85" width="30" height="30" fill="#E91E63">
    <animate
      attributeName="y"
      from="85" to="145"
      dur="1.5s"
      begin="click+1s"
      fill="freeze"/>
    <animate
      attributeName="fill"
      from="#E91E63" to="#FF5722"
      dur="1.5s"
      begin="click+1s"
      fill="freeze"/>
  </rect>
  
  <!-- Подсказка -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Квадрат начнет падать через 1с после клика
  </text>
</svg>
''',
      timing: 'begin="click+1s"',
      eventType: 'delayed click',
    ),
    _EventExample(
      name: 'Multi-Click',
      description: 'Каждый клик запускает новую анимацию',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Несколько элементов, реагирующих на клик -->
  <circle cx="100" cy="100" r="20" fill="#F44336">
    <animate
      attributeName="cy"
      from="100" to="50"
      dur="0.8s"
      begin="click"
      fill="remove"
      repeatCount="1"/>
  </circle>
  
  <circle cx="200" cy="100" r="20" fill="#2196F3">
    <animate
      attributeName="cy"
      from="100" to="50"
      dur="0.8s"
      begin="click"
      fill="remove"
      repeatCount="1"/>
  </circle>
  
  <circle cx="300" cy="100" r="20" fill="#4CAF50">
    <animate
      attributeName="cy"
      from="100" to="50"
      dur="0.8s"
      begin="click"
      fill="remove"
      repeatCount="1"/>
  </circle>
  
  <!-- Подсказка -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Кликайте несколько раз!
  </text>
  
  <text x="200" y="180" text-anchor="middle" font-size="12" fill="#999">
    Анимация повторяется при каждом клике
  </text>
</svg>
''',
      timing: 'begin="click" (multiple)',
      eventType: 'multi-click',
    ),
    _EventExample(
      name: 'Event Chain',
      description: 'Клик запускает цепочку анимаций',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Первая анимация - по клику -->
  <rect x="20" y="80" width="30" height="30" fill="#673AB7">
    <animate id="anim1"
      attributeName="x"
      from="20" to="120"
      dur="1s"
      begin="click"
      fill="freeze"/>
  </rect>
  
  <!-- Вторая начинается когда первая заканчивается -->
  <rect x="150" y="80" width="30" height="30" fill="#3F51B5">
    <animate id="anim2"
      attributeName="x"
      from="150" to="250"
      dur="1s"
      begin="anim1.end"
      fill="freeze"/>
  </rect>
  
  <!-- Третья начинается когда вторая заканчивается -->
  <rect x="280" y="80" width="30" height="30" fill="#2196F3">
    <animate
      attributeName="x"
      from="280" to="380"
      dur="1s"
      begin="anim2.end"
      fill="freeze"/>
  </rect>
  
  <!-- Подсказка -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Клик запускает цепную реакцию
  </text>
  
  <text x="200" y="170" text-anchor="middle" font-size="11" fill="#999">
    click → anim1 → anim2 → anim3
  </text>
</svg>
''',
      timing: 'Event chain',
      eventType: 'chain',
    ),
    _EventExample(
      name: 'Interactive Button',
      description: 'Интерактивная кнопка с анимированной обратной связью',
      svgData: '''
<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">
  <!-- Кнопка -->
  <g id="button">
    <rect x="125" y="70" width="150" height="60" rx="30" fill="#FF5722">
      <animate
        attributeName="fill"
        from="#FF5722" to="#E64A19"
        dur="0.2s"
        begin="click"
        fill="freeze"/>
      <animate
        attributeName="fill"
        from="#E64A19" to="#FF5722"
        dur="0.2s"
        begin="click+0.2s"
        fill="freeze"/>
    </rect>
    
    <!-- Текст кнопки -->
    <text x="200" y="107" text-anchor="middle" font-size="20" fill="white">
      НАЖМИ!
      <animate
        attributeName="font-size"
        from="20" to="18"
        dur="0.2s"
        begin="click"
        fill="freeze"/>
      <animate
        attributeName="font-size"
        from="18" to="20"
        dur="0.2s"
        begin="click+0.2s"
        fill="freeze"/>
    </text>
    
    <!-- Эффект ripple -->
    <circle cx="200" cy="100" r="0" fill="white" opacity="0.5">
      <animate
        attributeName="r"
        from="0" to="80"
        dur="0.6s"
        begin="click"
        fill="remove"/>
      <animate
        attributeName="opacity"
        from="0.5" to="0"
        dur="0.6s"
        begin="click"
        fill="remove"/>
    </circle>
  </g>
  
  <!-- Подсказка -->
  <text x="200" y="30" text-anchor="middle" font-size="14" fill="#666">
    Интерактивная кнопка с эффектом нажатия
  </text>
  
  <!-- Индикатор нажатий -->
  <text x="200" y="175" text-anchor="middle" font-size="12" fill="#999">
    ✓ Клики регистрируются
  </text>
</svg>
''',
      timing: 'Interactive button',
      eventType: 'interactive',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final example = _examples[_selectedExample];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Селектор примеров
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event-Based Timing Examples',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: _examples
                      .asMap()
                      .entries
                      .map(
                        (e) => ButtonSegment<int>(
                          value: e.key,
                          label: Text(
                            e.value.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  selected: {_selectedExample},
                  onSelectionChanged: (Set<int> selected) {
                    setState(() {
                      _selectedExample = selected.first;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // SVG область
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 500,
                      maxHeight: 300,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedSvgPicture.string(
                        example.svgData,
                        autoPlay: widget.autoPlay,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Информационная панель
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.touch_app, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      example.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  example.description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.code, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Timing:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        example.timing,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Event Type:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        example.eventType,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue.withAlpha(
                        (0.1 * 255).round(),
                      ),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getEventInfo(example.eventType),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getEventInfo(String eventType) {
    switch (eventType) {
      case 'click':
        return 'Анимация запускается при клике на SVG область. '
            'Используйте begin="click" в элементе <animate>.';
      case 'hover':
        return 'Анимация запускается при наведении мыши. '
            'Используйте begin="mouseover" и begin="mouseout".';
      case 'delayed click':
        return 'Анимация запускается с задержкой после события. '
            'Используйте begin="click+1s" для задержки в 1 секунду.';
      case 'multi-click':
        return 'Каждое событие перезапускает анимацию. '
            'Анимации с repeatCount="1" сбрасываются при новом событии.';
      case 'chain':
        return 'События могут запускать цепочки анимаций. '
            'Комбинируйте begin="click" и begin="anim1.end".';
      case 'interactive':
        return 'Создавайте интерактивные UI элементы с visual feedback. '
            'Комбинируйте несколько анимаций для сложных эффектов.';
      default:
        return 'Event-based анимации позволяют создавать интерактивный SVG контент.';
    }
  }
}

class _EventExample {
  final String name;
  final String description;
  final String svgData;
  final String timing;
  final String eventType;

  const _EventExample({
    required this.name,
    required this.description,
    required this.svgData,
    required this.timing,
    required this.eventType,
  });
}
