import 'package:flutter/material.dart';

enum SvgCategory {
  characters,
  logos,
  loaders,
  icons,
  buttons,
  morphing,
  text,
  path,
  effects3d,
  backgrounds,
  charts,
  appUI,
  general,
}

extension SvgCategoryX on SvgCategory {
  String get label => switch (this) {
        SvgCategory.characters => 'Characters',
        SvgCategory.logos => 'Logos',
        SvgCategory.loaders => 'Loaders',
        SvgCategory.icons => 'Icons',
        SvgCategory.buttons => 'Buttons & UI',
        SvgCategory.morphing => 'Morphing',
        SvgCategory.text => 'Text',
        SvgCategory.path => 'Path',
        SvgCategory.effects3d => '3D Effects',
        SvgCategory.backgrounds => 'Backgrounds',
        SvgCategory.charts => 'Charts',
        SvgCategory.appUI => 'App UI',
        SvgCategory.general => 'General',
      };

  Color get color => switch (this) {
        SvgCategory.characters => const Color(0xFFE91E63),
        SvgCategory.logos => const Color(0xFF9C27B0),
        SvgCategory.loaders => const Color(0xFF2196F3),
        SvgCategory.icons => const Color(0xFF00BCD4),
        SvgCategory.buttons => const Color(0xFFFF9800),
        SvgCategory.morphing => const Color(0xFF4CAF50),
        SvgCategory.text => const Color(0xFFFF5722),
        SvgCategory.path => const Color(0xFFFFC107),
        SvgCategory.effects3d => const Color(0xFF673AB7),
        SvgCategory.backgrounds => const Color(0xFF607D8B),
        SvgCategory.charts => const Color(0xFF009688),
        SvgCategory.appUI => const Color(0xFF03A9F4),
        SvgCategory.general => const Color(0xFF78909C),
      };

  IconData get icon => switch (this) {
        SvgCategory.characters => Icons.emoji_emotions_outlined,
        SvgCategory.logos => Icons.auto_awesome_outlined,
        SvgCategory.loaders => Icons.hourglass_empty_rounded,
        SvgCategory.icons => Icons.interests_outlined,
        SvgCategory.buttons => Icons.touch_app_outlined,
        SvgCategory.morphing => Icons.transform_rounded,
        SvgCategory.text => Icons.text_fields_rounded,
        SvgCategory.path => Icons.route_outlined,
        SvgCategory.effects3d => Icons.view_in_ar_rounded,
        SvgCategory.backgrounds => Icons.wallpaper_rounded,
        SvgCategory.charts => Icons.bar_chart_rounded,
        SvgCategory.appUI => Icons.phone_iphone_rounded,
        SvgCategory.general => Icons.animation_rounded,
      };
}

class SvgAnimationItem {
  final String url;
  final String title;
  final SvgCategory category;

  const SvgAnimationItem({
    required this.url,
    required this.title,
    required this.category,
  });
}

String _titleFromUrl(String url) {
  final file = url.split('/').last.replaceAll('.svg', '');
  return file.split('-').map((w) {
    if (w.isEmpty) return '';
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
}

SvgCategory _categorize(String url) {
  final u = url.toLowerCase();
  if (u.contains('character') ||
      u.contains('skating') ||
      u.contains('dancing') ||
      u.contains('walking') ||
      u.contains('biker') ||
      u.contains('basketball') ||
      u.contains('bunny') ||
      u.contains('raccoon') ||
      u.contains('dog-charact') ||
      u.contains('icecream') ||
      u.contains('cactus') ||
      u.contains('robot') ||
      u.contains('parrot') ||
      u.contains('game-char') ||
      u.contains('jelly-bounce') ||
      u.contains('astronaut')) {
    return SvgCategory.characters;
  }
  if (u.contains('logo')) {
    return SvgCategory.logos;
  }
  if (u.contains('loader') ||
      u.contains('spinner') ||
      u.contains('preloader') ||
      u.contains('loading') ||
      u.contains('svg-animated-loaders') ||
      u.contains('simple-svg-animated') ||
      u.contains('cool-loaders') ||
      u.contains('cluttercore') ||
      u.contains('lego-for-app') ||
      u.contains('spooky-eyes') ||
      u.contains('anthropomorphic') ||
      u.contains('ping-pong') ||
      u.contains('stroke-paths-css') ||
      u.contains('moving-car') ||
      u.contains('burger-and-fries') ||
      u.contains('fingerprint') ||
      u.contains('neumorphic-css') ||
      u.contains('neumorphic-spinner')) {
    return SvgCategory.loaders;
  }
  if (u.contains('icon')) {
    return SvgCategory.icons;
  }
  if (u.contains('button') ||
      u.contains('toggle') ||
      u.contains('neumorphic-ui') ||
      u.contains('animated-cat-button') ||
      u.contains('animated-shopping') ||
      u.contains('animated-interactive') ||
      u.contains('animated-mobile-app-buttons') ||
      u.contains('neumorphism-buttons') ||
      u.contains('simple-animated-toggle')) {
    return SvgCategory.buttons;
  }
  if (u.contains('morph') ||
      u.contains('origami') ||
      u.contains('jellyfish')) {
    return SvgCategory.morphing;
  }
  if (u.contains('text') ||
      u.contains('typography') ||
      u.contains('writing') ||
      u.contains('neon-accents') ||
      u.contains('svg-text') ||
      u.contains('sales-animated') ||
      u.contains('dreams') ||
      u.contains('/glow') ||
      u.contains('vibe-text') ||
      u.contains('signature') ||
      u.contains('cyber-monday') ||
      u.contains('kinetic') ||
      u.contains('ciao-bella') ||
      u.contains('fine-cravings')) {
    return SvgCategory.text;
  }
  if (u.contains('-path') ||
      u.contains('path-') ||
      u.contains('map') ||
      u.contains('racetrack') ||
      u.contains('bouncing-ball') ||
      u.contains('infinity') ||
      u.contains('packman') ||
      u.contains('paper-plane') ||
      u.contains('isometric-path') ||
      u.contains('cookies-line') ||
      u.contains('line-animation') ||
      u.contains('animated-biker') ||
      u.contains('moving-car')) {
    return SvgCategory.path;
  }
  if (u.contains('3d') ||
      u.contains('faux') ||
      u.contains('fake-3d') ||
      u.contains('diamond') ||
      u.contains('soda-can') ||
      u.contains('card-flip') ||
      u.contains('distorted') ||
      u.contains('amber') ||
      u.contains('gaming-console')) {
    return SvgCategory.effects3d;
  }
  if (u.contains('background') ||
      u.contains('pattern') ||
      u.contains('geometric-shapes') ||
      u.contains('geometric-objects') ||
      u.contains('cool-shapes') ||
      u.contains('animated-js-svg') ||
      u.contains('funky-wall')) {
    return SvgCategory.backgrounds;
  }
  if (u.contains('chart') ||
      u.contains('graph') ||
      u.contains('Animated-Neumorphic') ||
      u.contains('neumorphic-chart') ||
      u.contains('export-types') ||
      u.contains('formats-user') ||
      u.contains('happy-chart') ||
      u.contains('industry') ||
      u.contains('evolution') ||
      u.contains('types-of-projects') ||
      u.contains('time-investment') ||
      u.contains('completion-in-time')) {
    return SvgCategory.charts;
  }
  if (u.contains('app') ||
      u.contains('mobile') ||
      u.contains('onboarding') ||
      u.contains('login') ||
      u.contains('succes-state') ||
      u.contains('mailbox') ||
      u.contains('message-delivered') ||
      u.contains('spilled-paint') ||
      u.contains('404') ||
      u.contains('stopwatch') ||
      u.contains('mixed-media') ||
      u.contains('animated-animals-ui') ||
      u.contains('learning-app') ||
      u.contains('vr-svg') ||
      u.contains('process')) {
    return SvgCategory.appUI;
  }
  return SvgCategory.general;
}

SvgAnimationItem _item(String url) =>
    SvgAnimationItem(url: url, title: _titleFromUrl(url), category: _categorize(url));

final List<SvgAnimationItem> kAllAnimations = [
  // ── General / Misc ──────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2024/10/glowing-gummies-graphic-art-animation.svg'),
  _item('https://cdn.svgator.com/images/2024/10/coffee-match-cut-animation-1.svg'),
  _item('https://cdn.svgator.com/images/2023/03/stopwatch-svg-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/vr-svg-animation-example.svg'),
  _item('https://cdn.svgator.com/images/2023/03/cool-shapes-animated-using-svg.svg'),
  _item('https://cdn.svgator.com/images/2023/03/wind-blowing-in-may-svg-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/message-delivered-to-mailbox-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-js-svg-example.svg'),
  // ── Characters ──────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2023/03/animated-green-astronaut-helmet.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-skating-girls.svg'),
  _item('https://cdn.svgator.com/images/2024/10/jelly-bounce-bunny-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/12/animated-icecream-characters.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/11/animated-game-characters.svg'),
  _item('https://www.svgator.com/blog/content/files/2026/01/ramen-raccoon-motion-graphics.svg'),
  _item('https://cdn.svgator.com/images/2024/11/dog-character-animation.svg'),
  _item('https://cdn.svgator.com/images/2024/02/animated-character-using-laptop.svg'),
  _item('https://cdn.svgator.com/images/2023/03/chose-the-hotel-character-svg-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-dancing-blue-cactus.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-basketball-boy.svg'),
  _item('https://cdn.svgator.com/images/2024/10/robot-character-light-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-man-walking-his-dog.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/07/bunny-chasing-carrot-loader-animation.svg'),
  // ── Logos ───────────────────────────────────────────────────────────────────
  _item('https://www.svgator.com/blog/content/files/2025/07/proprtyai-animated-logo.svg'),
  _item('https://cdn.svgator.com/images/2023/03/luckypaint-svg-animated-logo.svg'),
  _item('https://cdn.svgator.com/images/2024/02/layerbase-animated-logo.svg'),
  _item('https://www.svgator.com/blog/content/files/2026/01/svgator-logo-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/voltsuite-logo-animated-svg.svg'),
  _item('https://cdn.svgator.com/images/2023/03/musicat-animated-logo-example.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-parrot-logo.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-hocus-logo.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-sniff-logo.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-bee-krafty-logo.svg'),
  // ── Loaders ─────────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2023/03/svg-animated-loaders.svg'),
  _item('https://cdn.svgator.com/images/2023/03/simple-svg-animated-loaders.svg'),
  _item('https://cdn.svgator.com/images/2023/03/cool-loaders-svg-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/12/cluttercore-plants.svg'),
  _item('https://cdn.svgator.com/images/2024/04/animated-lego-for-app-loading-page.svg'),
  _item('https://cdn.svgator.com/images/2023/06/halloween-spooky-eyes-loading-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/06/anthropomorphic-characters-preloader.svg'),
  _item('https://cdn.svgator.com/images/2023/06/ping-pong-css-loader.svg'),
  _item('https://cdn.svgator.com/images/2023/06/stroke-paths-css-loaders.svg'),
  _item('https://cdn.svgator.com/images/2023/06/moving-car-css-preloader.svg'),
  _item('https://cdn.svgator.com/images/2023/06/self-assembling-burger-and-fries-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/06/fingerprint-scan-css-loader.svg'),
  _item('https://cdn.svgator.com/images/2023/06/neumorphic-css-spinner.svg'),
  // ── Icons ───────────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/assets/landing-pages/create-animated-svg-icons/f2-gallery-grey-icons.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/09/fitness-app-icon-animations.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/09/90s-retro-animated-icons.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/09/health-care-animated-icons.svg'),
  _item('https://cdn.svgator.com/images/2023/09/social-media-animated-icons.svg'),
  _item('https://cdn.svgator.com/images/2023/09/file-types-animated-icons.svg'),
  _item('https://cdn.svgator.com/images/2023/09/cloud-computing-icons.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/07/animated-notion-style-icons.svg'),
  _item('https://cdn.svgator.com/images/2024/02/how-to-animate-icons-example.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-icons-set-gradients.svg'),
  _item('https://cdn.svgator.com/images/2023/03/svg-animated-ecommerce-icons-set.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-shopping-icons.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-interactive-icons.svg'),
  _item('https://cdn.svgator.com/images/2024/11/animated-icons-explaining-a-process.svg'),
  // ── Buttons & UI ────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2021/08/interactive-animations.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-cat-button.svg'),
  _item('https://cdn.svgator.com/images/2024/02/neumorphic-ui-icons.svg'),
  _item('https://cdn.svgator.com/images/2024/04/animated-mobile-app-buttons.svg'),
  _item('https://cdn.svgator.com/images/2025/03/animated-toggle-switch.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-toggle-button-smiley-face.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-neumorphism-buttons.svg'),
  _item('https://cdn.svgator.com/images/2023/03/simple-animated-toggle-buttons.svg'),
  // ── Morphing ────────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2024/02/strawberry-chocolate-morph-animation.svg'),
  _item('https://cdn.svgator.com/images/2024/10/mobile-app-morphing-animation.svg'),
  _item('https://cdn.svgator.com/images/2024/10/animated-morphing-flame-waving.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-origami-bird-flying-.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-svg-morph-jellyfish.svg'),
  _item('https://cdn.svgator.com/images/2023/03/svg-animated-morph-example.svg'),
  _item('https://cdn.svgator.com/images/2024/02/Donut-Hover-Animation.svg'),
  // ── Path animations ─────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/assets/landing-pages/animate-svg-along-path/5th-fold-taxi-map.svg'),
  _item('https://cdn.svgator.com/assets/landing-pages/animate-svg-along-path/fold2/examples/paper-plane-path.svg'),
  _item('https://cdn.svgator.com/assets/landing-pages/animate-svg-along-path/fold2/examples/infinity-path.svg'),
  _item('https://cdn.svgator.com/assets/landing-pages/animate-svg-along-path/fold2/examples/packman-burger.svg'),
  _item('https://cdn.svgator.com/assets/landing-pages/animate-svg-along-path/fold2/examples/racetrack-path-animation.svg'),
  _item('https://cdn.svgator.com/assets/landing-pages/animate-svg-along-path/6th-fold-isometric-path.svg'),
  _item('https://cdn.svgator.com/images/2023/03/cookies-line-svg-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-biker.svg'),
  _item('https://cdn.svgator.com/images/2023/03/line-animation-of-city.svg'),
  _item('https://cdn.svgator.com/assets/landing-pages/animate-svg-along-path/4th-fold-bouncing-ball.svg'),
  // ── 3D Effects ──────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2024/10/3d-faux-animated-soda-can.svg'),
  _item('https://cdn.svgator.com/images/2023/03/svg-animated-diamond-shape.svg'),
  _item('https://cdn.svgator.com/images/2024/10/fake-3d-cat-in-a-box-animation.svg'),
  _item('https://cdn.svgator.com/images/2024/10/fake-3d-pencil-turn-motion-graphics.svg'),
  _item('https://cdn.svgator.com/images/2024/10/fake-3d-card-flip-effect.svg'),
  _item('https://cdn.svgator.com/images/2023/12/distorted-fly-trapped-in-amber.svg'),
  _item('https://www.svgator.com/blog/content/files/2026/04/gaming-console-animation.svg'),
  _item('https://cdn.svgator.com/images/2025/03/fake-3d-kinetic-typography.svg'),
  // ── Text ────────────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2023/03/animated-text-fine-cravings.svg'),
  _item('https://cdn.svgator.com/images/2024/10/ciao-bella-writing-neon-accents-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/svg-text-animation-dreams.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/11/signature-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/sales-animated-text.svg'),
  _item('https://cdn.svgator.com/images/2023/12/glow.svg'),
  _item('https://www.svgator.com/blog/content/files/2026/01/text-to-animate-in-svgator.svg'),
  _item('https://www.svgator.com/blog/content/files/2026/04/vibe-text-colorful-style.svg'),
  _item('https://www.svgator.com/blog/content/files/2026/01/cyber-monday-motion-design.svg'),
  // ── Backgrounds ─────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2023/03/animated-geometric-shapes-background.svg'),
  _item('https://cdn.svgator.com/images/2023/03/js-svg-animated-geometric-objects-background.svg'),
  _item('https://cdn.svgator.com/images/2024/02/Animated-background-example.svg'),
  _item('https://cdn.svgator.com/images/2022/06/background-svg-image-pattern.svg'),
  _item('https://cdn.svgator.com/images/2024/10/funky-wall-pattern--match-cut-animation.svg'),
  // ── Charts ──────────────────────────────────────────────────────────────────
  _item('https://www.svgator.com/blog/content/files/2025/09/export-types-trends-chart-animation.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/09/svgators-evolution-export-formats.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/09/happy-chart-competition-animation.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/09/formats-user-type-graph-animated-chart.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/11/chart-showing-types-of-projects-made-by-designers-in-SVGartor.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/11/animation-completion-in-time-animated-chart.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/11/animated-chart-showing-types-of-projects-made-by-developers-in-svgator.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/11/animated-chart-showing-time-investment-per-animation-type-in-svgator.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/09/industry-preffered-formats-svg-animated-chart.svg'),
  // ── App UI ───────────────────────────────────────────────────────────────────
  _item('https://cdn.svgator.com/images/2024/11/succes-state-animation-mailbox.svg'),
  _item('https://cdn.svgator.com/images/2024/04/spilled-paint-404-page-animation.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/07/animated-animals-ui-design-in-a-mobile-device-mockup.svg'),
  _item('https://cdn.svgator.com/images/2024/04/mobile-app-login-animation-1.svg'),
  _item('https://cdn.svgator.com/images/2021/11/onboarding-animation-mobile-apps-1.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/11/app-page-animation.svg'),
  _item('https://cdn.svgator.com/images/2024/04/app-onboarding-animation-example.svg'),
  _item('https://cdn.svgator.com/images/2025/03/learning-app-animation.svg'),
  _item('https://cdn.svgator.com/images/2024/02/mixed-media-animation-example.svg'),
  _item('https://www.svgator.com/blog/content/files/2025/07/mobile-product-sale-animation.svg'),
  _item('https://cdn.svgator.com/images/2023/03/animated-man-walking-his-dog.svg'),
];
