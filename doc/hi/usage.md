# full_svg_flutter उपयोग गाइड

`full_svg_flutter` Flutter ऐप्स में असली SVG files को सीधे render करने के लिए बनाया गया है। यह साधारण static SVG icons और illustrations के साथ-साथ complex animated SVG files भी संभालता है: SMIL, CSS `@keyframes`, path morphing, filters, masks, rich text, और SVGator JavaScript exports.

इस गाइड का उपयोग तब करें जब आपको package install करना हो, `flutter_svg` से migrate करना हो, सही widget चुनना हो, animation control करना हो, या किसी SVG rendering issue को debug करना हो।

## 1. Installation

Package जोड़ें:

```bash
flutter pub add full_svg_flutter
```

या `pubspec.yaml` में dependency लिखें:

```yaml
dependencies:
  full_svg_flutter: ^1.4.3
```

Dart file में import करें:

```dart
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

Local SVG assets के लिए files या folder register करें:

```yaml
flutter:
  assets:
    - assets/icons/
    - assets/animations/logo.svg
```

फिर चलाएं:

```bash
flutter pub get
```

## 2. कौन सा widget इस्तेमाल करें?

| Use case | Widget | क्यों |
|---|---|---|
| Static icons, logos, illustrations | `SvgPicture` | familiar `flutter_svg` API के साथ compatible |
| File static है या animated, यह पक्का नहीं | `FSvgPicture` | animation markers detect करके सही renderer चुनता है |
| Play, pause, seek, speed, reverse, या SVG `<view>` switching चाहिए | `AnimatedSvgPicture` + `AnimatedSvgController` | animation runtime पर direct control देता है |
| Static app को `flutter_svg` से migrate करना है | `SvgPicture` | आम तौर पर सिर्फ import बदलता है |
| SVGator JS export या custom inline SVG script | `FSvgPicture` या `AnimatedSvgPicture` | embedded QuickJS bridge से SVG JavaScript चलाता है |

Recommended default:

```dart
FSvgPicture.asset('assets/graphic.svg')
```

`FSvgPicture` रोजमर्रा के उपयोग के लिए सबसे सुरक्षित choice है, क्योंकि यह static और animated दोनों SVG संभालता है। SVG में animation markers नहीं हैं तो static `SvgPicture` path इस्तेमाल होता है। SMIL, CSS animation, या script-driven animation मिले तो `AnimatedSvgPicture` path इस्तेमाल होता है।

## 3. Quick start examples

### Asset

```dart
FSvgPicture.asset(
  'assets/animations/flutter_logo_animated.svg',
  width: 210,
  height: 210,
  fit: BoxFit.contain,
  semanticsLabel: 'Animated Flutter logo',
)
```

### Network

```dart
FSvgPicture.network(
  'https://example.com/hero.svg',
  width: 320,
  placeholderBuilder: (context) => const SizedBox(
    width: 48,
    height: 48,
    child: CircularProgressIndicator(),
  ),
  errorBuilder: (context, error, stackTrace) {
    return const Icon(Icons.broken_image);
  },
)
```

### Raw SVG string

```dart
const rawSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="40" fill="#1976d2"/>
</svg>
''';

FSvgPicture.string(rawSvg, width: 100, height: 100)
```

### Memory bytes

```dart
final bytes = utf8.encode(rawSvg);

FSvgPicture.memory(
  Uint8List.fromList(bytes),
  width: 100,
  height: 100,
)
```

### File

```dart
FSvgPicture.file(
  file,
  width: 240,
  height: 240,
)
```

`FSvgPicture.file` mainly non-web platforms के लिए है, क्योंकि browser security rules direct `file://` access को restrict करते हैं।

## 4. Static SVG rendering

अगर केवल static SVG चाहिए, तो `SvgPicture` इस्तेमाल करें। इसका public API `flutter_svg` जैसा रखा गया है:

```dart
SvgPicture.asset(
  'assets/icons/settings.svg',
  width: 24,
  height: 24,
  colorFilter: const ColorFilter.mode(
    Color(0xff333333),
    BlendMode.srcIn,
  ),
  semanticsLabel: 'Settings',
)
```

Common constructors:

```dart
SvgPicture.asset('assets/icon.svg')
SvgPicture.network('https://example.com/icon.svg')
SvgPicture.string(rawSvg)
SvgPicture.memory(bytes)
SvgPicture.file(file)
```

`renderingStrategy` argument API compatibility के लिए रखा गया है। Package अपना DOM-preserving renderer इस्तेमाल करता है और painted output internally cache करता है।

## 5. Animated SVG rendering

अधिकतर animated SVG files के लिए:

```dart
FSvgPicture.asset(
  'assets/animations/spinner.svg',
  width: 64,
  height: 64,
  autoPlay: true,
  playbackRate: 1.0,
)
```

`FSvgPicture` animation arguments:

| Argument | मतलब |
|---|---|
| `autoPlay` | Animation automatically start हो। Default `true` |
| `playbackRate` | Speed multiplier. `1.0` normal, `0.5` half speed, `2.0` double speed |
| `initialTime` | Timeline के किसी specific time से start करना |
| `backgroundColor` | Animated rendering के पीछे background color |

Static SVG files पर ये arguments harmless हैं।

## 6. Playback control

जब app को buttons, sliders, scrubbing, reverse playback, या named SVG `<view>` switching चाहिए, तब `AnimatedSvgPicture` directly इस्तेमाल करें।

```dart
class ControlledSvgDemo extends StatefulWidget {
  const ControlledSvgDemo({super.key});

  @override
  State<ControlledSvgDemo> createState() => _ControlledSvgDemoState();
}

class _ControlledSvgDemoState extends State<ControlledSvgDemo> {
  final AnimatedSvgController controller = AnimatedSvgController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSvgPicture.asset(
          'assets/animations/loader.svg',
          controller: controller,
          autoPlay: false,
          width: 160,
          height: 160,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: controller.resume,
            ),
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: controller.pause,
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: controller.restart,
            ),
          ],
        ),
      ],
    );
  }
}
```

Controller API:

```dart
controller.pause();
controller.resume();
controller.togglePlayPause();

controller.seek(const Duration(seconds: 2));
controller.restart();

controller.setPlaybackRate(0.5);
controller.setPlaybackRate(2.0);

controller.reverse();
controller.forward();
controller.toggleDirection();

controller.switchToView('detail');
controller.switchToView(null);
```

Useful controller state:

```dart
final paused = controller.isPaused;
final rate = controller.playbackRate;
final reversed = controller.isReversed;
final views = controller.availableViews;
final timeMs = controller.currentTimeMs;
```

अगर UI को playback state के साथ update करना है, तो `controller.addListener` use करें।

## 7. SVGator और JavaScript SVGs

SVGator animations को declarative SMIL/CSS या JavaScript-driven SVG के रूप में export कर सकता है। `full_svg_flutter` दोनों support करता है।

```dart
FSvgPicture.asset(
  'assets/svgator/character.svg',
  width: 300,
  height: 300,
)
```

जब SVG में `<script>` होता है, package embedded QuickJS runtime start करता है और polyfilled SVG DOM expose करता है। Common APIs जैसे `document.getElementById`, `setAttribute`, `requestAnimationFrame`, timers, `addEventListener`, `getTotalLength`, और `getPointAtLength` available हैं।

महत्वपूर्ण सीमाएं:

- Runtime SVG DOM bridge है, full browser नहीं।
- `window.location`, History, IndexedDB, WebGL, और HTML layout जैसे browser APIs available नहीं हैं।
- Intended use case SVGator player scripts और simple custom SVG scripts हैं।
- जिन SVG files में `<script>` नहीं है, वे JavaScript runtime cost नहीं देतीं।

## 8. Styling, colors, और themes

### `colorFilter`

जब पूरी SVG को tint करना हो, `colorFilter` use करें:

```dart
FSvgPicture.asset(
  'assets/icons/bell.svg',
  colorFilter: const ColorFilter.mode(
    Colors.red,
    BlendMode.srcIn,
  ),
)
```

यह single-color icons के लिए अच्छा है। Detailed illustrations के लिए अक्सर सही नहीं होता, क्योंकि यह हर painted pixel को affect करता है।

### `ColorMapper`

जब केवल specific source colors बदलने हों, `ColorMapper` use करें:

```dart
class BrandColorMapper extends ColorMapper {
  const BrandColorMapper(this.primary);

  final Color primary;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == const Color(0xff0057ff)) {
      return primary;
    }
    return color;
  }
}

FSvgPicture.asset(
  'assets/logo.svg',
  colorMapper: BrandColorMapper(Theme.of(context).colorScheme.primary),
)
```

### `currentColor`

अगर SVG `currentColor` इस्तेमाल करता है, तो `SvgTheme` दें:

```dart
FSvgPicture.asset(
  'assets/icon-current-color.svg',
  theme: const SvgTheme(currentColor: Colors.green),
)
```

## 9. Layout और accessibility

SVG widgets Flutter layout widgets के साथ normal तरीके से काम करते हैं:

```dart
SizedBox.square(
  dimension: 48,
  child: FSvgPicture.asset(
    'assets/icons/profile.svg',
    fit: BoxFit.contain,
    semanticsLabel: 'Profile',
  ),
)
```

Important layout arguments:

| Argument | मतलब |
|---|---|
| `width`, `height` | Requested render size |
| `fit` | SVG box में कैसे fit होगा, जैसे `BoxFit.contain` |
| `alignment` | Allocated box के अंदर alignment |
| `matchTextDirection` | RTL context में horizontal flip |
| `allowDrawingOutsideViewBox` | SVG viewBox के बाहर paint allow करना |
| `clipBehavior` / `clipToViewBox` | Clipping behavior control करना |

Accessibility:

```dart
FSvgPicture.asset(
  'assets/illustrations/success.svg',
  semanticsLabel: 'Payment completed',
)
```

Decorative SVG:

```dart
FSvgPicture.asset(
  'assets/background-shape.svg',
  excludeFromSemantics: true,
)
```

## 10. External images, fonts, links, और foreignObject

Advanced hooks `AnimatedSvgPicture` पर मिलते हैं।

### Custom image loading

```dart
AnimatedSvgPicture.asset(
  'assets/composite.svg',
  imageLoader: (href) async {
    if (href.startsWith('app://')) {
      return loadBytesFromYourStore(href);
    }
    return null;
  },
)
```

### Links

```dart
AnimatedSvgPicture.asset(
  'assets/map.svg',
  onLinkTap: (link) {
    debugPrint('Tapped ${link.href}');
  },
)
```

### foreignObject

`<foreignObject>` parse होता है, लेकिन arbitrary HTML default रूप से render नहीं होता। अगर content आपके app का है और आप Flutter widget replacement देना चाहते हैं, तो `AnimatedSvgPicture` पर `foreignObjectBuilder` use करें।

## 11. Performance recommendations

- Bundled SVG files के लिए `FSvgPicture.asset` prefer करें।
- Repeated icons में same asset path reuse करें ताकि cache मदद कर सके।
- Rebuild-heavy widgets में huge inline SVG strings avoid करें।
- जहां possible हो, `const` constructors use करें।
- Large SVG widgets को stable dimensions दें, जैसे `SizedBox`, `AspectRatio`, या constraints।
- JS-driven SVG static SVG से expensive होते हैं; fidelity जरूरी हो तभी use करें।
- Heavy filters, large paths, और hundreds of animated elements low-end devices पर frame rate affect कर सकते हैं।

SVG decode cache tune किया जा सकता है:

```dart
svg.cache.maximumSize = 200;
```

## 12. flutter_svg से migration

Static SVG के लिए dependency और import बदलें:

```dart
// Before
import 'package:flutter_svg/flutter_svg.dart';

// After
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

अधिकतर calls वैसे ही रहेंगी:

```dart
SvgPicture.asset('assets/icon.svg')
SvgPicture.network('https://example.com/icon.svg')
SvgPicture.string(rawSvg)
SvgPicture.memory(bytes)
```

Animated SVG के लिए:

```dart
FSvgPicture.asset('assets/spinner.svg')
```

`AnimatedSvgPicture` तभी directly use करें जब controller या advanced hooks चाहिए हों।

Dedicated notes के लिए [migration_from_flutter_svg.md](../migration_from_flutter_svg.md) देखें।

## 13. Supported SVG features

Common support areas:

- basic shapes, paths, groups, `<defs>`, `<use>`, `<symbol>`
- transforms, gradients, patterns, masks, clip paths
- सभी 17 SVG filter primitives
- rich text, `<tspan>`, `<textPath>`, bidi/RTL, decorations
- SMIL: `<animate>`, `<animateTransform>`, `<animateMotion>`, `<set>`
- CSS `@keyframes`, transitions, variables, `calc()`, selectors
- path morphing और motion paths
- assets, network, data URI, और native `file://` से `<image>`
- `<a>` links, hit-testing, title/desc accessibility metadata
- SVGator-style inline JavaScript animation

Detailed matrix के लिए [supported_features.md](../supported_features.md) देखें।

## 14. Known limitations

`full_svg_flutter` browser engine नहीं है। मुख्य limitations:

- JavaScript polyfilled SVG DOM पर चलता है, complete web platform पर नहीं।
- `<foreignObject>` content default रूप से HTML की तरह render नहीं होता।
- Cross-origin external resources platform permissions पर depend करते हैं।
- Extreme filter chains या text layout cases browsers से अलग दिख सकते हैं।
- Malformed SVG files को cleanup की जरूरत पड़ सकती है।
- Web platform पर `file://` image references काम नहीं करते।

Details के लिए [limitations.md](../limitations.md) देखें।

## 15. Troubleshooting

### Asset दिखाई नहीं दे रहा

`pubspec.yaml` में asset registered है या नहीं, indentation सही है या नहीं, और `flutter pub get` चला है या नहीं, यह check करें।

```yaml
flutter:
  assets:
    - assets/logo.svg
```

### SVG static दिख रहा है, animate नहीं हो रहा

Animated files के लिए `SvgPicture` की जगह `FSvgPicture` या `AnimatedSvgPicture` use करें।

```dart
FSvgPicture.asset('assets/animated.svg')
```

### Animation automatically start नहीं होना चाहिए

```dart
FSvgPicture.asset(
  'assets/animated.svg',
  autoPlay: false,
)
```

बाद में playback control चाहिए तो controller के साथ `AnimatedSvgPicture` use करें।

### Network SVG load नहीं हो रहा

URL, HTTPS certificate, app network permissions, और platform security policy check करें। Authenticated requests के लिए headers दें:

```dart
FSvgPicture.network(
  url,
  headers: {'Authorization': 'Bearer $token'},
)
```

### Color गलत दिख रहा है

`colorFilter` तभी use करें जब पूरी SVG tint करनी हो। Precise color replacement के लिए `ColorMapper` use करें या SVG को `currentColor` के साथ author करें।

### SVGator file सही render नहीं हो रही

उसी SVG को browser में खोलकर compare करें। अगर यह JavaScript export है, तो check करें कि वह SVG DOM bridge के बाहर के browser APIs पर depend तो नहीं कर रहा। Bug report में original SVG file, expected browser screenshot, actual Flutter screenshot, platform, Flutter version, और package version शामिल करें।

## 16. Minimal complete example

```dart
import 'package:flutter/material.dart';
import 'package:full_svg_flutter/full_svg_flutter.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SVG demo')),
        body: Center(
          child: FSvgPicture.asset(
            'assets/flutter_logo_animated.svg',
            width: 210,
            height: 210,
            semanticsLabel: 'Animated Flutter logo',
          ),
        ),
      ),
    );
  }
}
```
