import 'package:flutter/material.dart';
import 'package:flutter_svg/src/animation/animated_svg_picture.dart';

/// Демонстрационное приложение для анимированных SVG
///
/// Показывает различные типы SMIL анимаций:
/// - Движение (x, y)
/// - Размер (width, height, r)
/// - Прозрачность (opacity)
/// - RepeatCount indefinite
void main() {
  runApp(const AnimatedSvgDemo());
}

class AnimatedSvgDemo extends StatelessWidget {
  const AnimatedSvgDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Animated SVG Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animated SVG Examples')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ExampleCard(
            title: '1. Движение слева направо',
            svgXml: '''
              <svg viewBox="0 0 100 50">
                <rect x="0" y="15" width="20" height="20" fill="blue">
                  <animate attributeName="x" from="0" to="80" dur="2s" repeatCount="indefinite"/>
                </rect>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '2. Пульсирующий круг',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <circle cx="50" cy="50" r="10" fill="red">
                  <animate attributeName="r" from="10" to="40" dur="1s" repeatCount="indefinite"/>
                </circle>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '3. Затухание',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <rect x="25" y="25" width="50" height="50" fill="green">
                  <animate attributeName="opacity" from="1" to="0" dur="2s" repeatCount="indefinite"/>
                </rect>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '4. Изменение размера',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <rect x="25" y="25" width="10" height="10" fill="purple">
                  <animate attributeName="width" from="10" to="50" dur="1.5s" repeatCount="indefinite"/>
                  <animate attributeName="height" from="10" to="50" dur="1.5s" repeatCount="indefinite"/>
                </rect>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '5. Keyframe анимация (values + keyTimes)',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <circle cx="50" cy="50" r="20" fill="orange">
                  <animate 
                    attributeName="cx" 
                    values="20;80;20" 
                    keyTimes="0;0.5;1"
                    dur="3s" 
                    repeatCount="indefinite"/>
                </circle>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '6. Дискретная анимация (discrete)',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <rect x="10" y="40" width="20" height="20" fill="cyan">
                  <animate 
                    attributeName="x" 
                    values="10;40;70" 
                    calcMode="discrete"
                    dur="1.5s" 
                    repeatCount="indefinite"/>
                </rect>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '7. Несколько элементов',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <circle cx="20" cy="50" r="8" fill="red">
                  <animate attributeName="cy" from="50" to="20" dur="1s" repeatCount="indefinite"/>
                </circle>
                <circle cx="50" cy="50" r="8" fill="green">
                  <animate attributeName="cy" from="50" to="80" dur="1s" repeatCount="indefinite"/>
                </circle>
                <circle cx="80" cy="50" r="8" fill="blue">
                  <animate attributeName="cy" from="50" to="20" dur="1s" repeatCount="indefinite"/>
                </circle>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '8. Анимация цвета заливки (fill)',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <rect x="25" y="25" width="50" height="50" fill="red">
                  <animate attributeName="fill" from="#ff0000" to="#0000ff" dur="2s" repeatCount="indefinite"/>
                </rect>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '9. Анимация цвета обводки (stroke)',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <circle cx="50" cy="50" r="30" fill="none" stroke="#00ff00" stroke-width="4">
                  <animate attributeName="stroke" from="#00ff00" to="#ff00ff" dur="3s" repeatCount="indefinite"/>
                </circle>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '10. Keyframe цветовая анимация',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <rect x="20" y="20" width="60" height="60" fill="#ff0000">
                  <animate 
                    attributeName="fill" 
                    values="#ff0000;#00ff00;#0000ff;#ff0000" 
                    keyTimes="0;0.33;0.66;1"
                    dur="4s" 
                    repeatCount="indefinite"/>
                </rect>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '11. Комбинированная анимация (размер + цвет)',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <circle cx="50" cy="50" r="15" fill="#ff6b6b">
                  <animate attributeName="r" from="15" to="35" dur="2s" repeatCount="indefinite"/>
                  <animate attributeName="fill" from="#ff6b6b" to="#4ecdc4" dur="2s" repeatCount="indefinite"/>
                </circle>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '12. Вращение (rotate transform)',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <rect x="40" y="40" width="20" height="20" fill="#ff6b6b">
                  <animateTransform
                    attributeName="transform"
                    type="rotate"
                    from="0 50 50"
                    to="360 50 50"
                    dur="2s"
                    repeatCount="indefinite"/>
                </rect>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '13. Перемещение (translate transform)',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <circle cx="20" cy="50" r="10" fill="#4ecdc4">
                  <animateTransform
                    attributeName="transform"
                    type="translate"
                    from="0 0"
                    to="60 0"
                    dur="1.5s"
                    repeatCount="indefinite"/>
                </circle>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '14. Масштабирование (scale transform)',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <g transform="translate(50, 50)">
                  <rect x="-15" y="-15" width="30" height="30" fill="#9b59b6">
                    <animateTransform
                      attributeName="transform"
                      type="scale"
                      from="1"
                      to="2"
                      dur="1s"
                      repeatCount="indefinite"/>
                  </rect>
                </g>
              </svg>
            ''',
          ),
          SizedBox(height: 16),
          _ExampleCard(
            title: '15. Комбинированная трансформация',
            svgXml: '''
              <svg viewBox="0 0 100 100">
                <rect x="35" y="35" width="30" height="30" fill="#e74c3c">
                  <animateTransform
                    attributeName="transform"
                    type="rotate"
                    from="0 50 50"
                    to="180 50 50"
                    dur="2s"
                    repeatCount="indefinite"/>
                </rect>
              </svg>
            ''',
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.title, required this.svgXml});

  final String title;
  final String svgXml;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: AnimatedSvgPicture.string(
                  svgXml,
                  width: 300,
                  height: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
