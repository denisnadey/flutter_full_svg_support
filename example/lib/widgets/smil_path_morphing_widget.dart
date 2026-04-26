import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';

import 'animation_theme.dart';

/// SMIL Path Morphing Examples Widget
class SMILPathMorphingWidget extends StatefulWidget {
  const SMILPathMorphingWidget({super.key, this.autoPlay = true});

  /// Whether to automatically start playing animations
  final bool autoPlay;

  @override
  State<SMILPathMorphingWidget> createState() => _SMILPathMorphingWidgetState();
}

class _SMILPathMorphingWidgetState extends State<SMILPathMorphingWidget> {
  int _selectedExample = 0;

  final List<_PathMorphExample> _examples = const [
    _PathMorphExample(
      name: 'Square to Circle',
      svg: '''
        <svg viewBox="0 0 100 100">
          <path 
            fill="#4CAF50" 
            stroke="#2196F3" 
            stroke-width="2"
            d="M10,10 L90,10 L90,90 L10,90 Z">
            <animate 
              attributeName="d" 
              from="M10,10 L90,10 L90,90 L10,90 Z"
              to="M50,10 A40,40 0 0,1 90,50 A40,40 0 0,1 50,90 A40,40 0 0,1 10,50 A40,40 0 0,1 50,10 Z"
              dur="3s" 
              repeatCount="indefinite"/>
            <animate 
              attributeName="fill" 
              from="#4CAF50" 
              to="#9C27B0" 
              dur="3s" 
              repeatCount="indefinite"/>
          </path>
        </svg>
      ''',
    ),
    _PathMorphExample(
      name: 'Star to Heart',
      svg: '''
        <svg viewBox="0 0 100 100">
          <path 
            fill="#FFC107" 
            stroke="#FF5722" 
            stroke-width="2"
            d="M50,10 L61,35 L90,35 L67,52 L78,85 L50,65 L22,85 L33,52 L10,35 L39,35 Z">
            <animate 
              attributeName="d" 
              from="M50,10 L61,35 L90,35 L67,52 L78,85 L50,65 L22,85 L33,52 L10,35 L39,35 Z"
              to="M50,90 C50,90 20,65 20,45 C20,30 27,20 40,20 C47,20 50,25 50,25 C50,25 53,20 60,20 C73,20 80,30 80,45 C80,65 50,90 50,90 Z"
              dur="2.5s" 
              repeatCount="indefinite"/>
            <animate 
              attributeName="fill" 
              from="#FFC107" 
              to="#F44336" 
              dur="2.5s" 
              repeatCount="indefinite"/>
          </path>
        </svg>
      ''',
    ),
    _PathMorphExample(
      name: 'Triangle to Hexagon',
      svg: '''
        <svg viewBox="0 0 100 100">
          <path 
            fill="#2196F3" 
            stroke="#009688" 
            stroke-width="2"
            d="M50,10 L90,85 L10,85 Z">
            <animate 
              attributeName="d" 
              from="M50,10 L90,85 L10,85 Z"
              to="M50,10 L85,30 L85,70 L50,90 L15,70 L15,30 Z"
              dur="2s" 
              repeatCount="indefinite"/>
            <animate 
              attributeName="fill" 
              from="#2196F3" 
              to="#00BCD4" 
              dur="2s" 
              repeatCount="indefinite"/>
          </path>
        </svg>
      ''',
    ),
    _PathMorphExample(
      name: 'Complex Path',
      svg: '''
        <svg viewBox="0 0 200 200">
          <path 
            fill="#E91E63" 
            fill-opacity="0.8"
            stroke="#9C27B0" 
            stroke-width="3"
            d="M100,50 L120,90 L160,90 L130,115 L145,155 L100,130 L55,155 L70,115 L40,90 L80,90 Z">
            <animate 
              attributeName="d" 
              dur="4s"
              repeatCount="indefinite"
              values="
                M100,50 L120,90 L160,90 L130,115 L145,155 L100,130 L55,155 L70,115 L40,90 L80,90 Z;
                M100,180 C100,180 40,140 40,100 C40,70 55,50 80,50 C95,50 100,60 100,60 C100,60 105,50 120,50 C145,50 160,70 160,100 C160,140 100,180 100,180 Z;
                M100,60 A40,40 0 0,1 140,100 A40,40 0 0,1 100,140 A40,40 0 0,1 60,100 A40,40 0 0,1 100,60 Z;
                M100,50 L120,90 L160,90 L130,115 L145,155 L100,130 L55,155 L70,115 L40,90 L80,90 Z
              "
              keyTimes="0;0.33;0.66;1"/>
            <animate 
              attributeName="fill" 
              dur="4s" 
              repeatCount="indefinite"
              values="#E91E63;#F44336;#9C27B0;#E91E63"
              keyTimes="0;0.33;0.66;1"/>
          </path>
        </svg>
      ''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final example = _examples[_selectedExample];

    return Column(
      children: [
        // Example selector
        Container(
          padding: const EdgeInsets.all(AnimationTheme.spacingMedium),
          decoration: AnimationTheme.getControlPanelDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SMIL Path Morphing',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AnimationTheme.spacingMedium),
              SegmentedButton<int>(
                segments: _examples
                    .asMap()
                    .entries
                    .map(
                      (e) => ButtonSegment(
                        value: e.key,
                        label: Text(
                          e.value.name,
                          key: Key('button_${e.value.name}'),
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

        // Animation display
        Expanded(
          child: Container(
            decoration: AnimationTheme.getAnimationDisplayDecoration(context),
            margin: const EdgeInsets.all(AnimationTheme.spacingMedium),
            child: Center(
              child: AnimatedSvgPicture.string(
                example.svg,
                width: 300,
                height: 300,
                autoPlay: widget.autoPlay,
              ),
            ),
          ),
        ),

        // Info panel
        Container(
          padding: const EdgeInsets.all(AnimationTheme.spacingLarge),
          decoration: AnimationTheme.getControlPanelDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                example.name,
                key: const Key('info_panel_title'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AnimationTheme.spacingSmall),
              Text(
                'Using <animate attributeName="d"> for path morphing',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AnimationTheme.spacingMedium),
              const Divider(),
              const SizedBox(height: AnimationTheme.spacingSmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfo(context, 'Type', 'SMIL'),
                  _buildInfo(context, 'Attribute', 'd (path)'),
                  _buildInfo(context, 'Repeat', '∞'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AnimationTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PathMorphExample {
  const _PathMorphExample({required this.name, required this.svg});

  final String name;
  final String svg;
}
