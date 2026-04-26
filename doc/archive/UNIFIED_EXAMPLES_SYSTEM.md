# Unified Examples System

## Overview

A unified examples system with tabs, FPS monitoring, and a consistent design has been created.

## Architecture

### 1. Main Page (`UnifiedExamplesPage`)

**File**: `example/lib/pages/unified_examples_page.dart`

#### Features:
- **Tabs (TabBar)**: 4 example categories
  1. SMIL Animations - basic SMIL animations
  2. Path Morphing - path morphing
  3. Metrics - metrics demo
  4. Custom - custom examples

- **FPS Monitor**: Built-in performance monitor
  - Shows current FPS
  - FPS graph for the last 60 frames
  - Color indicator (green ≥55, orange ≥30, red <30)
  - Frame counter
  - Toggled via a button in AppBar

- **Floating FPS widget**: Positioned above content

### 2. Reusable Widgets

#### PathMorphingWidget
**File**: `example/lib/widgets/path_morphing_widget.dart`

**Examples:**
- Square ↔ Circle
- Star ↔ Heart  
- Triangle ↔ Hexagon

**Features:**
- Segmented button for example selection
- Color interpolation
- AnimationController with play/pause
- Uses AnimationControlPanel

#### MetricsWidget
**File**: `example/lib/widgets/metrics_widget.dart`

**Features:**
- SVG animation display
- Panel with metrics (elements, animations, duration)
- Hint about using FPS monitor

### 3. Unified Theme

**AnimationTheme** (`example/lib/widgets/animation_theme.dart`)

#### Constants:
```dart
// Colors
primaryColor = Color(0xFF2196F5)
secondaryColor = Color(0xFF4CAF50)

// Spacing
spacingSmall = 8.0
spacingMedium = 16.0
spacingLarge = 24.0
spacingXLarge = 32.0

// Border Radius
radiusSmall = 8.0
radiusMedium = 12.0
radiusLarge = 16.0

// Size Constraints
animationDisplayMinHeight = 300.0
animationDisplayMaxWidth = 600.0
controlPanelMinHeight = 180.0
```

#### Components:
- **AnimationControlPanel**: Control panel with progress slider, play/pause/reset buttons
- **AnimationExampleLayout**: Wrapper for example pages
- **getLightTheme()**: Light theme
- **getDarkTheme()**: Dark theme

### 4. FPS Monitor

**Components:**
- `FPSMonitor` widget - main widget
- `_FPSMonitorState` - state with FPS calculation
- `_FPSGraphPainter` - graph rendering

**Metrics:**
- Current FPS (average over 60 frames)
- FPS history graph
- Frame counter
- Color-coded performance indicator

**Technical details:**
```dart
// FPS calculation
fps = 1000000 / deltaTime.inMicroseconds

// History storage
_fpsHistory (max 60 values)

// Colors
green: fps >= 55
orange: fps >= 30 && fps < 55
red: fps < 30
```

## File Structure

```
example/lib/
├── main.dart (updated - uses AnimationTheme)
├── pages/
│   ├── home_page.dart (updated - single path to UnifiedExamplesPage)
│   └── unified_examples_page.dart (NEW - main tabbed page)
├── widgets/
│   ├── animation_theme.dart (existing - unified theme)
│   ├── path_morphing_widget.dart (NEW - morphing widget)
│   └── metrics_widget.dart (NEW - metrics widget)
└── l10n/
    └── app_localizations.dart (updated - new strings added)
```

## Usage

### Running the app:

```bash
cd example
flutter run
```

### Navigation:

1. Home page → "View Examples" button
2. UnifiedExamplesPage with tabs opens
3. Press the speed icon (top-right) for FPS monitor
4. Switch between tabs for different examples

### Adding a new example:

**Option 1: New tab**

```dart
// In UnifiedExamplesPage add:
TabController(length: 5, vsync: this) // increase count

Tab(
  icon: const Icon(Icons.your_icon),
  text: 'Your Tab',
)

// Create a new Tab widget
class _YourTab extends StatelessWidget {
  const _YourTab({required this.showFPS});
  final bool showFPS;
  
  @override
  Widget build(BuildContext context) {
    return YourWidget();
  }
}
```

**Option 2: Add to an existing widget**

```dart
// For example, add a new example to PathMorphingWidget:
_MorphingExample(
  name: 'Your Shape',
  path1: 'M...',
  path2: 'M...',
  color1: Colors.color1,
  color2: Colors.color2,
)
```

## Advantages

### 1. Consistent Style
- All examples use AnimationTheme
- Consistent colors, spacing, radii
- Light/Dark mode support

### 2. FPS Monitoring
- Built into all tabs
- No separate page needed
- Real-time, visual graph

### 3. Organization
- Tabs instead of multiple pages
- Easy to add new examples
- Reusable components

### 4. UX
- Quick switching between examples
- Single entry point
- Clear navigation

### 5. Performance
- FPS graph shows smoothness
- Easy to test different examples
- Visual feedback

## Localization

New strings added to `app_localizations.dart`:

**English:**
- `smil_animations`: "SMIL Animations"
- `metrics`: "Metrics"

**Russian:**
- `smil_animations`: "SMIL Анимации"
- `metrics`: "Метрики"

## Technical Details

### FPS Calculation

```dart
void _onFrame(Duration timestamp) {
  if (_lastFrameTime != Duration.zero) {
    final delta = timestamp - _lastFrameTime;
    final fps = 1000000 / delta.inMicroseconds;
    
    // Add to history (max 60)
    _fpsHistory.add(fps);
    if (_fpsHistory.length > 60) {
      _fpsHistory.removeAt(0);
    }
  }
  _lastFrameTime = timestamp;
  SchedulerBinding.instance.addPostFrameCallback(_onFrame);
}
```

### FPS Graph Painter

```dart
class _FPSGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final maxFPS = 60.0;
    final stepX = size.width / (history.length - 1);
    
    for (int i = 0; i < history.length; i++) {
      final x = i * stepX;
      final y = size.height - (history[i] / maxFPS * size.height);
      // Draw line path
    }
    
    // Draw filled area + line + 60fps reference
  }
}
```

### Theme Application

```dart
// main.dart
MaterialApp(
  theme: AnimationTheme.getLightTheme(),
  darkTheme: AnimationTheme.getDarkTheme(),
  themeMode: ThemeMode.system,
)
```

## Next Steps

### Possible Improvements:

1. **More examples**
   - AnimateMotion examples
   - Complex path morphing
   - Color animations showcase

2. **Extended metrics**
   - Memory usage
   - Paint time
   - Build time

3. **Save settings**
   - FPS monitor on/off state
   - Last selected tab
   - Theme preference

4. **Export/Share**
   - Screenshot of current animation
   - Export SVG code
   - Share examples

5. **Performance Profiling**
   - Detailed frame timeline
   - Jank detection
   - Optimization suggestions

## Status

- ✅ UnifiedExamplesPage with tabs created
- ✅ FPS Monitor integrated
- ✅ Reusable widgets created
- ✅ Unified theme applied
- ✅ Localization updated
- ✅ All examples connected
- ✅ All files compile without errors

## Testing

```bash
# Analyze
cd example
flutter analyze

# Run
flutter run -d macos

# Test FPS Monitor
# 1. Open examples
# 2. Press the speed icon
# 3. Check FPS display
# 4. Switch tabs
# 5. Verify FPS updates
```

---

**Date**: November 21, 2025  
**Status**: ✅ Completed  
**Files created**: 3  
**Files updated**: 3  
**Lines of code**: ~700
