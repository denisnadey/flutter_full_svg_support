import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:full_svg_flutter/full_svg_flutter.dart' as ffsf;

import '../widgets/fps_hud.dart';

/// "Galactic Storm" — single mega stress-test asset that exercises every
/// advanced feature full_svg_flutter supports. Everything moves; nothing is
/// static. Buttery-smooth via cubic-bezier `calcMode="spline"` easing.
///
///   - 500 distant stars: drift translate + twinkle, each with unique vectors
///   - 100 bright stars: orbital `animateMotion` + rotating cross-rays + pulse
///   - 50 floating particles: long-range `animateMotion` along curves
///   - 30 nebula clouds: feGaussianBlur, animated rx/ry/rotation
///   - 10 morphing crystals: drift translate + path d-morph + rotation
///   - 10 streaking comets: animateMotion + animated radius
///   - 1 central core: rotating rings, animated stop-color + stop-offset,
///     path morphing on the accretion disk, drop-shadow filter
///   - 1 arc text: textPath + skewY twist + letter-spacing + fill cycle
///   - 1 flying twisting text: textPath on a MORPHING curve + skewX twist +
///     scrolling startOffset + colour cycle + font-size pulse
///   - 5 CSS `@keyframes` shapes (pulse / spin / drift)
///   - Animated linear-gradient cosmic background
///
/// Total: ~3,070 elements · 854 `<animate>` · 653 `<animateTransform>` ·
/// 160 `<animateMotion>` — **1,667 concurrent animations** on a single asset.
///
/// flutter_svg cannot render most of these features. The rendered output
/// will be a static frame at best.
class MegaStressBenchmarkScreen extends StatefulWidget {
  const MegaStressBenchmarkScreen({super.key});

  @override
  State<MegaStressBenchmarkScreen> createState() =>
      _MegaStressBenchmarkScreenState();
}

class _MegaStressBenchmarkScreenState extends State<MegaStressBenchmarkScreen>
    with SingleTickerProviderStateMixin {
  static const String _asset = 'assets/stress/galactic_storm.svg';

  _Variant _variant = _Variant.fullSvgFlutter;
  bool _hudVisible = true;
  bool _hudVerbose = true;
  bool _showInfoCard = true;

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.keyM) {
      setState(() => _hudVisible = !_hudVisible);
      return true;
    } else if (k == LogicalKeyboardKey.keyV) {
      setState(() => _hudVerbose = !_hudVerbose);
      return true;
    } else if (k == LogicalKeyboardKey.keyI) {
      setState(() => _showInfoCard = !_showInfoCard);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Galactic Storm — Mega Stress'),
          actions: [
            IconButton(
              tooltip: 'Toggle HUD (M)',
              icon: Icon(_hudVisible ? Icons.speed : Icons.speed_outlined),
              onPressed: () => setState(() => _hudVisible = !_hudVisible),
            ),
            IconButton(
              tooltip: 'Toggle verbose metrics (V)',
              icon: Icon(_hudVerbose ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _hudVerbose = !_hudVerbose),
            ),
            IconButton(
              tooltip: 'Toggle info card (I)',
              icon: Icon(_showInfoCard ? Icons.info : Icons.info_outline),
              onPressed: () => setState(() => _showInfoCard = !_showInfoCard),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<_Variant>(
                segments: const [
                  ButtonSegment(
                    value: _Variant.fullSvgFlutter,
                    label: Text('full_svg_flutter'),
                    icon: Icon(Icons.bolt),
                  ),
                  ButtonSegment(
                    value: _Variant.flutterSvg,
                    label: Text('flutter_svg'),
                    icon: Icon(Icons.compare),
                  ),
                ],
                selected: {_variant},
                onSelectionChanged: (s) => setState(() => _variant = s.first),
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            Positioned.fill(child: _buildSvg()),
            // FPS HUD — top-right, isolated via RepaintBoundary inside.
            Positioned(
              top: 12,
              right: 12,
              child: FpsHud(
                visible: _hudVisible,
                verbose: _hudVerbose,
                label: _variant == _Variant.fullSvgFlutter
                    ? 'full_svg_flutter'
                    : 'flutter_svg',
              ),
            ),
            // Feature description card — bottom.
            if (_showInfoCard)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _StatsOverlay(variant: _variant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSvg() {
    switch (_variant) {
      case _Variant.fullSvgFlutter:
        return ffsf.FSvgPicture.asset(
          _asset,
          fit: BoxFit.cover,
          autoPlay: true,
          errorBuilder: (_, e, __) => _ErrorView(error: e),
        );
      case _Variant.flutterSvg:
        return fsvg.SvgPicture.asset(
          _asset,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
    }
  }
}

enum _Variant { fullSvgFlutter, flutterSvg }

class _StatsOverlay extends StatelessWidget {
  const _StatsOverlay({required this.variant});

  final _Variant variant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.45,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              variant == _Variant.fullSvgFlutter
                  ? 'full_svg_flutter • all animations live'
                  : 'flutter_svg • static snapshot (animations not supported)',
              style: TextStyle(
                color: variant == _Variant.fullSvgFlutter
                    ? Colors.cyanAccent
                    : Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            const Text('~3,070 elements · 854 <animate> · 653 <animateTransform>'),
            const Text('160 <animateMotion> · 1,667 concurrent animations'),
            const Text('All particles drift / orbit · 2 text elements skew + scroll'),
            const Text('cubic-bezier easing on every long animation (spline)'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to render: $error',
            style: const TextStyle(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ),
      );
}
