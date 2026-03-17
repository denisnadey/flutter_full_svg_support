import 'package:flutter/material.dart';

/// Shared theme and styles for all animation examples
class AnimationTheme {
  // Colors
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;
  static const Color darkCardColor = Color(0xFF1E1E1E);

  // Spacing
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // Animation display size
  static const double animationDisplayMinHeight = 300.0;
  static const double animationDisplayMaxHeight = 500.0;

  // Mobile breakpoint
  static const double mobileBreakpoint = 600.0;

  // Control panel height
  static const double controlPanelHeight = 200.0;
  static const double controlPanelHeightMobile = 180.0;

  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        showValueIndicator: ShowValueIndicator.onDrag,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 4,
      ),
    );
  }

  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: spacingLarge,
            vertical: spacingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      sliderTheme: const SliderThemeData(
        showValueIndicator: ShowValueIndicator.onDrag,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 4,
      ),
    );
  }

  static BoxDecoration getControlPanelDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < mobileBreakpoint;

    return BoxDecoration(
      color: isDark ? darkCardColor : cardColor,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isMobile ? radiusMedium : radiusLarge),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
          blurRadius: isMobile ? 8 : 16,
          offset: Offset(0, isMobile ? -2 : -4),
        ),
      ],
    );
  }

  static BoxDecoration getAnimationDisplayDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < mobileBreakpoint;

    return BoxDecoration(
      color: isDark ? darkCardColor : cardColor,
      borderRadius: BorderRadius.circular(
        isMobile ? radiusSmall : radiusMedium,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
          blurRadius: isMobile ? 4 : 8,
          offset: Offset(0, isMobile ? 1 : 2),
        ),
      ],
    );
  }

  /// Get responsive padding based on screen size
  static double getResponsivePadding(
    BuildContext context, {
    double mobile = spacingMedium,
    double desktop = spacingLarge,
  }) {
    return MediaQuery.of(context).size.width < mobileBreakpoint
        ? mobile
        : desktop;
  }

  /// Get responsive font size
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    required double desktop,
  }) {
    return MediaQuery.of(context).size.width < mobileBreakpoint
        ? mobile
        : desktop;
  }
}

/// Reusable control panel widget for animation examples
class AnimationControlPanel extends StatelessWidget {
  const AnimationControlPanel({
    super.key,
    required this.controller,
    required this.onPlayPause,
    required this.onReset,
    this.title,
    this.subtitle,
    this.additionalControls,
    this.showProgress = true,
  });

  final AnimationController controller;
  final VoidCallback onPlayPause;
  final VoidCallback onReset;
  final String? title;
  final String? subtitle;
  final Widget? additionalControls;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AnimationTheme.getControlPanelDecoration(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AnimationTheme.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              if (title != null) ...[
                Text(
                  title!,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AnimationTheme.spacingSmall),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AnimationTheme.spacingMedium),
              ],

              // Additional controls (e.g., shape selector)
              if (additionalControls != null) ...[
                additionalControls!,
                const SizedBox(height: AnimationTheme.spacingMedium),
              ],

              // Progress slider
              if (showProgress) ...[
                Row(
                  children: [
                    Text('0%', style: Theme.of(context).textTheme.bodySmall),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, child) {
                          return Slider(
                            value: controller.value,
                            onChanged: (value) {
                              controller.value = value;
                            },
                            label: '${(controller.value * 100).toInt()}%',
                          );
                        },
                      ),
                    ),
                    Text('100%', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: AnimationTheme.spacingSmall),
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    return Text(
                      'Progress: ${(controller.value * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AnimationTheme.spacingMedium),
              ],

              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onPlayPause,
                    icon: AnimatedBuilder(
                      animation: controller,
                      builder: (context, child) {
                        return Icon(
                          controller.isAnimating
                              ? Icons.pause
                              : Icons.play_arrow,
                        );
                      },
                    ),
                    label: AnimatedBuilder(
                      animation: controller,
                      builder: (context, child) {
                        return Text(controller.isAnimating ? 'Pause' : 'Play');
                      },
                    ),
                  ),
                  const SizedBox(width: AnimationTheme.spacingMedium),
                  ElevatedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layout wrapper for animation examples
class AnimationExampleLayout extends StatelessWidget {
  const AnimationExampleLayout({
    super.key,
    required this.title,
    required this.animationDisplay,
    required this.controlPanel,
    this.headerWidget,
  });

  final String title;
  final Widget animationDisplay;
  final Widget controlPanel;
  final Widget? headerWidget;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: Column(
        children: [
          // Optional header (e.g., tabs, selectors)
          if (headerWidget != null) headerWidget!,

          // Animation display area
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AnimationTheme.spacingLarge),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 600,
                    minHeight: AnimationTheme.animationDisplayMinHeight,
                  ),
                  child: Container(
                    decoration: AnimationTheme.getAnimationDisplayDecoration(
                      context,
                    ),
                    padding: const EdgeInsets.all(AnimationTheme.spacingLarge),
                    child: animationDisplay,
                  ),
                ),
              ),
            ),
          ),

          // Control panel
          controlPanel,
        ],
      ),
    );
  }
}
