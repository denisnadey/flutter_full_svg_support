# full_svg_flutter 使用指南

`full_svg_flutter` 让 Flutter 应用可以直接渲染真实的 SVG 文件。它不仅适合普通静态 SVG，也适合复杂动画 SVG：SMIL、CSS `@keyframes`、路径变形、滤镜、遮罩、富文本，以及 SVGator 的 JavaScript 导出文件。

如果你想安装这个库、从 `flutter_svg` 迁移、选择合适的组件、控制动画播放，或者排查 SVG 显示问题，可以从本指南开始。

## 1. 安装

添加依赖：

```bash
flutter pub add full_svg_flutter
```

也可以手动修改 `pubspec.yaml`：

```yaml
dependencies:
  full_svg_flutter: ^1.4.3
```

在 Dart 文件中导入：

```dart
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

如果 SVG 是本地资源，需要在 `pubspec.yaml` 注册：

```yaml
flutter:
  assets:
    - assets/icons/
    - assets/animations/logo.svg
```

然后运行：

```bash
flutter pub get
```

## 2. 应该使用哪个组件？

| 场景 | 组件 | 原因 |
|---|---|---|
| 静态图标、Logo、插画 | `SvgPicture` | API 与常见的 `flutter_svg` 用法兼容 |
| 不确定文件是静态还是动画 | `FSvgPicture` | 自动检测动画标记并选择正确渲染器 |
| 需要播放、暂停、跳转、倍速、反向播放或切换 `<view>` | `AnimatedSvgPicture` + `AnimatedSvgController` | 可以直接控制动画运行时 |
| 从 `flutter_svg` 迁移静态 SVG | `SvgPicture` | 通常只需要改 import |
| SVGator JS 导出或自定义 SVG 内联脚本 | `FSvgPicture` 或 `AnimatedSvgPicture` | 通过内置 QuickJS 桥运行 SVG JavaScript |

日常推荐默认写法：

```dart
FSvgPicture.asset('assets/graphic.svg')
```

`FSvgPicture` 同时适合静态和动画 SVG。没有动画时，它会走静态 `SvgPicture` 路径；检测到 SMIL、CSS 动画或脚本驱动动画时，它会走 `AnimatedSvgPicture` 路径。

## 3. 快速示例

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

### 网络 SVG

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

### 原始 SVG 字符串

```dart
const rawSvg = '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <circle cx="50" cy="50" r="40" fill="#1976d2"/>
</svg>
''';

FSvgPicture.string(rawSvg, width: 100, height: 100)
```

### 内存 bytes

```dart
final bytes = utf8.encode(rawSvg);

FSvgPicture.memory(
  Uint8List.fromList(bytes),
  width: 100,
  height: 100,
)
```

### 文件

```dart
FSvgPicture.file(
  file,
  width: 240,
  height: 240,
)
```

`FSvgPicture.file` 主要用于非 Web 平台，因为浏览器安全策略会限制直接访问 `file://`。

## 4. 静态 SVG 渲染

如果只需要静态 SVG，可以使用 `SvgPicture`。它保留了与 `flutter_svg` 类似的公开 API：

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

常用构造方法：

```dart
SvgPicture.asset('assets/icon.svg')
SvgPicture.network('https://example.com/icon.svg')
SvgPicture.string(rawSvg)
SvgPicture.memory(bytes)
SvgPicture.file(file)
```

`renderingStrategy` 参数保留是为了 API 兼容。当前包使用自己的 DOM 保留渲染器，并会在内部缓存绘制结果。

## 5. 动画 SVG 渲染

大多数动画 SVG 可以直接这样使用：

```dart
FSvgPicture.asset(
  'assets/animations/spinner.svg',
  width: 64,
  height: 64,
  autoPlay: true,
  playbackRate: 1.0,
)
```

`FSvgPicture` 的动画相关参数：

| 参数 | 含义 |
|---|---|
| `autoPlay` | 是否自动开始播放，默认 `true` |
| `playbackRate` | 播放速度倍数，`1.0` 正常，`0.5` 半速，`2.0` 二倍速 |
| `initialTime` | 从指定时间点开始 |
| `backgroundColor` | 动画渲染背景色 |

这些参数用于静态 SVG 时不会造成问题。

## 6. 控制动画播放

当应用需要按钮、滑块、拖动进度、反向播放或命名 `<view>` 切换时，直接使用 `AnimatedSvgPicture`。

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

控制器 API：

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

常用状态：

```dart
final paused = controller.isPaused;
final rate = controller.playbackRate;
final reversed = controller.isReversed;
final views = controller.availableViews;
final timeMs = controller.currentTimeMs;
```

如果 UI 需要跟随播放状态更新，可以使用 `controller.addListener`。

## 7. SVGator 和 JavaScript SVG

SVGator 可以导出声明式 SMIL/CSS 动画，也可以导出 JavaScript 驱动的 SVG。`full_svg_flutter` 两种都支持。

```dart
FSvgPicture.asset(
  'assets/svgator/character.svg',
  width: 300,
  height: 300,
)
```

当 SVG 包含 `<script>` 时，包会启动内置 QuickJS 运行时，并提供一个 SVG DOM polyfill。常见 API 包括 `document.getElementById`、`setAttribute`、`requestAnimationFrame`、timer、`addEventListener`、`getTotalLength` 和 `getPointAtLength`。

注意边界：

- 这是 SVG DOM 桥，不是完整浏览器。
- `window.location`、History、IndexedDB、WebGL、HTML layout 等浏览器 API 不可用。
- 主要目标是 SVGator player script 和简单自定义 SVG 脚本。
- 没有 `<script>` 的 SVG 不会承担 JavaScript 运行时成本。

## 8. 样式、颜色和主题

### `colorFilter`

当整个 SVG 都需要染色时使用 `colorFilter`：

```dart
FSvgPicture.asset(
  'assets/icons/bell.svg',
  colorFilter: const ColorFilter.mode(
    Colors.red,
    BlendMode.srcIn,
  ),
)
```

这最适合单色图标。对于复杂插画通常不合适，因为它会影响所有像素。

### `ColorMapper`

如果只想替换特定源颜色，使用 `ColorMapper`：

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

如果 SVG 使用 `currentColor`，可以传入 `SvgTheme`：

```dart
FSvgPicture.asset(
  'assets/icon-current-color.svg',
  theme: const SvgTheme(currentColor: Colors.green),
)
```

## 9. 布局和无障碍

SVG 组件可以放进 Flutter 普通布局：

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

重要布局参数：

| 参数 | 含义 |
|---|---|
| `width`, `height` | 期望渲染尺寸 |
| `fit` | SVG 如何适配盒子，例如 `BoxFit.contain` |
| `alignment` | 在分配空间内的对齐方式 |
| `matchTextDirection` | RTL 场景下水平翻转 |
| `allowDrawingOutsideViewBox` | 是否允许绘制到 viewBox 外 |
| `clipBehavior` / `clipToViewBox` | 控制裁剪行为 |

无障碍标签：

```dart
FSvgPicture.asset(
  'assets/illustrations/success.svg',
  semanticsLabel: 'Payment completed',
)
```

装饰性 SVG：

```dart
FSvgPicture.asset(
  'assets/background-shape.svg',
  excludeFromSemantics: true,
)
```

## 10. 外部图片、字体、链接和 foreignObject

`AnimatedSvgPicture` 提供高级 hook。

### 自定义图片加载

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

### 链接

```dart
AnimatedSvgPicture.asset(
  'assets/map.svg',
  onLinkTap: (link) {
    debugPrint('Tapped ${link.href}');
  },
)
```

### foreignObject

`<foreignObject>` 会被解析，但默认不会渲染任意 HTML。如果内容由你的应用控制，并且想用 Flutter widget 替代，可以在 `AnimatedSvgPicture` 上使用 `foreignObjectBuilder`。

## 11. 性能建议

- 对打包资源优先使用 `FSvgPicture.asset`。
- 重复图标尽量复用同一个 asset 路径，让缓存发挥作用。
- 避免在频繁 rebuild 的组件中创建巨大的内联 SVG 字符串。
- 可以使用 `const` 的地方尽量使用。
- 给大型 SVG 稳定尺寸，例如 `SizedBox`、`AspectRatio` 或明确约束。
- JS 驱动 SVG 比静态 SVG 更昂贵，适合需要高保真动画的场景。
- 复杂滤镜、大路径和大量动画元素可能影响低端设备帧率，需要真机测试。

可以调整 SVG 解码缓存：

```dart
svg.cache.maximumSize = 200;
```

## 12. 从 flutter_svg 迁移

静态 SVG 通常只需要改依赖和 import：

```dart
// Before
import 'package:flutter_svg/flutter_svg.dart';

// After
import 'package:full_svg_flutter/full_svg_flutter.dart';
```

多数调用可以继续使用：

```dart
SvgPicture.asset('assets/icon.svg')
SvgPicture.network('https://example.com/icon.svg')
SvgPicture.string(rawSvg)
SvgPicture.memory(bytes)
```

动画 SVG 改用：

```dart
FSvgPicture.asset('assets/spinner.svg')
```

只有在需要控制器或高级 hook 时，才直接使用 `AnimatedSvgPicture`。

更多内容见 [migration_from_flutter_svg.md](../migration_from_flutter_svg.md)。

## 13. 支持的 SVG 特性

常见支持范围：

- 基础形状、路径、分组、`<defs>`、`<use>`、`<symbol>`
- transform、gradient、pattern、mask、clip path
- 全部 17 个 SVG filter primitive
- 富文本、`<tspan>`、`<textPath>`、bidi/RTL、装饰线
- SMIL：`<animate>`、`<animateTransform>`、`<animateMotion>`、`<set>`
- CSS `@keyframes`、transition、变量、`calc()`、selector
- 路径变形和 motion path
- 来自 asset、network、data URI、原生 `file://` 的 `<image>`
- `<a>` 链接、hit-testing、title/desc 无障碍元数据
- SVGator 风格的内联 JavaScript 动画

详细矩阵见 [supported_features.md](../supported_features.md)。

## 14. 已知限制

`full_svg_flutter` 不是浏览器引擎。主要限制：

- JavaScript 运行在 SVG DOM polyfill 上，不是完整 Web 平台。
- `<foreignObject>` 默认不会按 HTML 渲染。
- 跨域外部资源受平台权限限制。
- 极端滤镜链或文字排版场景可能与浏览器不同。
- 严重格式错误的 SVG 可能需要先清理。
- Web 平台不支持 `file://` 图片引用。

详见 [limitations.md](../limitations.md)。

## 15. 排查问题

### asset 不显示

检查 `pubspec.yaml` 是否注册、缩进是否正确，并确认运行过 `flutter pub get`。

```yaml
flutter:
  assets:
    - assets/logo.svg
```

### SVG 应该动画但没有动

使用 `FSvgPicture` 或 `AnimatedSvgPicture`，不要用 `SvgPicture`。

```dart
FSvgPicture.asset('assets/animated.svg')
```

### 不希望动画自动播放

```dart
FSvgPicture.asset(
  'assets/animated.svg',
  autoPlay: false,
)
```

如果之后还要手动播放，请使用带 controller 的 `AnimatedSvgPicture`。

### 网络 SVG 加载失败

检查 URL、HTTPS 证书、应用网络权限和平台安全策略。需要鉴权时传 headers：

```dart
FSvgPicture.network(
  url,
  headers: {'Authorization': 'Bearer $token'},
)
```

### 颜色不对

只有想给整个 SVG 染色时才用 `colorFilter`。精确替换颜色时使用 `ColorMapper`，或者在 SVG 中使用 `currentColor`。

### SVGator 文件显示不正确

先在浏览器中打开同一个 SVG 对比。如果它是 JavaScript 导出，检查是否使用了 SVG DOM 桥之外的浏览器 API。报告 bug 时请提供原始 SVG、浏览器期望截图、Flutter 实际截图、平台、Flutter 版本和包版本。

## 16. 最小完整示例

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
