# Example App - New Architecture

## Overview

A completely redesigned example application with clean code, simple state management, and maximum component reusability.

## Project Structure

```
example/lib/
├── main.dart                           # Entry point
├── state/
│   └── app_state.dart                 # State management (ChangeNotifier)
├── models/
│   └── svg_example.dart               # SVG example model
├── data/
│   └── examples_data.dart             # Collection of all examples
├── pages/
│   └── examples_page.dart             # Main page
└── widgets/
    ├── animated_svg_viewer.dart       # SVG viewer with parameters
    ├── parameters_panel.dart          # Parameter settings panel
    └── fps_monitor.dart               # FPS monitor
```

## Main Components

### 1. State Management (`app_state.dart`)

Simple ChangeNotifier for state management:

**AnimatedSvgPicture Parameters:**
- `width` / `height` - widget dimensions
- `fit` - BoxFit (contain, cover, fill, etc.)
- `alignment` - alignment (topLeft, center, etc.)
- `backgroundColor` - background color
- `playbackRate` - playback speed (0.1 - 5.0x)
- `autoPlay` - auto start
- `initialTime` - initial time

**UI Parameters:**
- `showFPS` - show FPS monitor
- `showParameters` - show parameters panel
- `selectedExampleIndex` - current example

### 2. Data Model (`svg_example.dart`)

```dart
class SvgExample {
  final String id;
  final String title;
  final String description;
  final String svgContent;
  final IconData icon;
  final String category;
  final List<String> tags;
}
```

**Categories:**
- Basic - basic animations (movement, pulsing, fading)
- Transform - transforms (rotation, translate, scale)
- Color - color animations
- Path - path morphing
- Motion - motion along a path (animateMotion)
- Advanced - complex combinations

### 3. Examples (`examples_data.dart`)

**13+ ready-made examples:**

**Basic:**
- Moving Rectangle - horizontal movement
- Pulsing Circle - pulsing circle
- Fading Square - opacity fade

**Transform:**
- Rotating Square - rotation
- Bouncing Ball - movement with easing
- Scaling Heart - scaling

**Color:**
- Rainbow Circle - rainbow fill
- Colorful Border - colored stroke

**Path:**
- Square to Circle - square-to-circle morph
- Star to Pentagon - star morph

**Motion:**
- Circle Path - movement along a circle
- Car on Track - car with auto-rotation

**Advanced:**
- Animated Clock - clock with multiple hands
- Loading Spinner - loading spinner

### 4. Widgets

**AnimatedSvgViewer** - displays AnimatedSvgPicture with the current parameters from AppState

**ParametersPanel** - interactive panel:
- Sliders for width/height/playbackRate
- autoPlay toggle
- Dropdown for fit/alignment
- Color chips for backgroundColor
- Reset to defaults button

**FPSMonitor** - performance monitoring:
- Current FPS
- History graph (60 frames)
- Color indicator (green >55, orange >30, red <30)

### 5. Main Page (`examples_page.dart`)

**Desktop layout:**
- Left panel (280px) - list of examples by category
- Center area - SVG with description and tags
- Right panel (320px) - parameters (optional)

**Mobile layout:**
- Horizontal scroll of examples at the top
- Center area - SVG
- Collapsible parameters panel at the bottom

## Usage

### Adding a New Example

```dart
// In examples_data.dart
SvgExample(
  id: 'my_example',
  title: 'My Example',
  description: 'Description of my animation',
  category: ExampleCategory.basic,
  icon: Icons.animation,
  tags: ['animate', 'custom'],
  svgContent: '''
<svg viewBox="0 0 100 100">
  <!-- Your SVG here -->
</svg>
  ''',
),
```

### Adding a New Category

```dart
// In svg_example.dart
class ExampleCategory {
  static const String myCategory = 'My Category';
}
```

### State Management

```dart
// Global state is available in main.dart
final _appState = AppState();

// Changing parameters
state.setWidth(400);
state.setPlaybackRate(2.0);
state.toggleFPS();
state.resetToDefaults();
```

## Implementation Notes

### Responsive Design
- Breakpoint: 900px
- Mobile < 900: vertical layout
- Desktop >= 900: three-column layout

### Performance
- ListenableBuilder for minimal redraws
- FPS monitor with 60-frame buffer
- Optimized sliders with divisions

### UX
- Visual feedback (selected example)
- Color-coded FPS indicator
- Intuitive icons for categories
- Tags for quick feature search

## Available AnimatedSvgPicture Parameters

All parameters are available in the interactive panel:

| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| width | double | 100-600 | Widget width |
| height | double | 100-600 | Widget height |
| fit | BoxFit | 7 options | How to fit SVG |
| alignment | Alignment | 9 positions | Alignment |
| backgroundColor | Color? | 6 presets | Container background |
| playbackRate | double | 0.1-5.0 | Animation speed |
| autoPlay | bool | true/false | Auto start |
| initialTime | Duration? | - | Initial time |

## Development Commands

```bash
# Run on macOS
cd example && flutter run -d macos

# Run on Chrome
cd example && flutter run -d chrome

# Run on iOS simulator
cd example && flutter run -d ios

# Hot reload
r

# Hot restart
R
```

## Architectural Advantages

✅ **Simplicity** - 5 files instead of 15+
✅ **Reusability** - all components are universal
✅ **Scalability** - easy to add examples
✅ **Code quality** - one pattern for all examples
✅ **State management** - simple ChangeNotifier with no dependencies
✅ **Performance** - minimal redraws
✅ **UX** - responsive design for mobile/desktop
✅ **Visualization** - all parameters available in the UI
