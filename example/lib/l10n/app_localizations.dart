import 'package:flutter/material.dart';

/// Application localization class
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English
    Locale('ru', ''), // Russian
  ];

  // General
  String get appTitle => _localizedStrings[locale.languageCode]!['app_title']!;
  String get language => _localizedStrings[locale.languageCode]!['language']!;
  String get switchLanguage =>
      _localizedStrings[locale.languageCode]!['switch_language']!;

  // Home page
  String get welcomeTitle =>
      _localizedStrings[locale.languageCode]!['welcome_title']!;
  String get welcomeSubtitle =>
      _localizedStrings[locale.languageCode]!['welcome_subtitle']!;
  String get viewExamples =>
      _localizedStrings[locale.languageCode]!['view_examples']!;
  String get viewMetrics =>
      _localizedStrings[locale.languageCode]!['view_metrics']!;

  // Examples
  String get examplesTitle =>
      _localizedStrings[locale.languageCode]!['examples_title']!;
  String get basicAnimations =>
      _localizedStrings[locale.languageCode]!['basic_animations']!;
  String get transformAnimations =>
      _localizedStrings[locale.languageCode]!['transform_animations']!;
  String get colorAnimations =>
      _localizedStrings[locale.languageCode]!['color_animations']!;
  String get pathAnimations =>
      _localizedStrings[locale.languageCode]!['path_animations']!;

  // Metrics
  String get metricsTitle =>
      _localizedStrings[locale.languageCode]!['metrics_title']!;
  String get realTimeMetrics =>
      _localizedStrings[locale.languageCode]!['real_time_metrics']!;
  String get fps => _localizedStrings[locale.languageCode]!['fps']!;
  String get frameTime =>
      _localizedStrings[locale.languageCode]!['frame_time']!;
  String get animationTime =>
      _localizedStrings[locale.languageCode]!['animation_time']!;
  String get totalDuration =>
      _localizedStrings[locale.languageCode]!['total_duration']!;
  String get currentTime =>
      _localizedStrings[locale.languageCode]!['current_time']!;
  String get progress => _localizedStrings[locale.languageCode]!['progress']!;
  String get playbackRate =>
      _localizedStrings[locale.languageCode]!['playback_rate']!;
  String get isPlaying =>
      _localizedStrings[locale.languageCode]!['is_playing']!;
  String get repeatCount =>
      _localizedStrings[locale.languageCode]!['repeat_count']!;

  // Control buttons
  String get play => _localizedStrings[locale.languageCode]!['play']!;
  String get pause => _localizedStrings[locale.languageCode]!['pause']!;
  String get reset => _localizedStrings[locale.languageCode]!['reset']!;
  String get restart => _localizedStrings[locale.languageCode]!['restart']!;

  // Animation examples
  String get rotation => _localizedStrings[locale.languageCode]!['rotation']!;
  String get translation =>
      _localizedStrings[locale.languageCode]!['translation']!;
  String get scale => _localizedStrings[locale.languageCode]!['scale']!;
  String get skewX => _localizedStrings[locale.languageCode]!['skew_x']!;
  String get skewY => _localizedStrings[locale.languageCode]!['skew_y']!;
  String get opacity => _localizedStrings[locale.languageCode]!['opacity']!;
  String get colorChange =>
      _localizedStrings[locale.languageCode]!['color_change']!;
  String get combined => _localizedStrings[locale.languageCode]!['combined']!;

  // Path morphing
  String get pathMorphing =>
      _localizedStrings[locale.languageCode]!['path_morphing']!;
  String get squareToCircle =>
      _localizedStrings[locale.languageCode]!['square_to_circle']!;
  String get starToHeart =>
      _localizedStrings[locale.languageCode]!['star_to_heart']!;
  String get triangleToHexagon =>
      _localizedStrings[locale.languageCode]!['triangle_to_hexagon']!;
  String get fromShape =>
      _localizedStrings[locale.languageCode]!['from_shape']!;
  String get toShape => _localizedStrings[locale.languageCode]!['to_shape']!;
  String get morphingProgress =>
      _localizedStrings[locale.languageCode]!['morphing_progress']!;

  // Descriptions
  String get rotationDesc =>
      _localizedStrings[locale.languageCode]!['rotation_desc']!;
  String get translationDesc =>
      _localizedStrings[locale.languageCode]!['translation_desc']!;
  String get scaleDesc =>
      _localizedStrings[locale.languageCode]!['scale_desc']!;
  String get skewXDesc =>
      _localizedStrings[locale.languageCode]!['skew_x_desc']!;
  String get skewYDesc =>
      _localizedStrings[locale.languageCode]!['skew_y_desc']!;
  String get opacityDesc =>
      _localizedStrings[locale.languageCode]!['opacity_desc']!;
  String get colorChangeDesc =>
      _localizedStrings[locale.languageCode]!['color_change_desc']!;
  String get combinedDesc =>
      _localizedStrings[locale.languageCode]!['combined_desc']!;
  String get pathMorphingDesc =>
      _localizedStrings[locale.languageCode]!['path_morphing_desc']!;

  // Unified examples
  String get smilAnimations =>
      _localizedStrings[locale.languageCode]!['smil_animations']!;
  String get metrics => _localizedStrings[locale.languageCode]!['metrics']!;

  static const Map<String, Map<String, String>> _localizedStrings = {
    'en': {
      'app_title': 'Flutter SVG Animations',
      'language': 'Language',
      'switch_language': 'Switch to Russian',
      'welcome_title': 'Welcome to Flutter SVG Animations',
      'welcome_subtitle': 'SMIL Animation Examples with Real-time Metrics',
      'view_examples': 'View Examples',
      'view_metrics': 'View Metrics Demo',
      'examples_title': 'Animation Examples',
      'basic_animations': 'Basic Animations',
      'transform_animations': 'Transform Animations',
      'color_animations': 'Color Animations',
      'path_animations': 'Path Animations',
      'metrics_title': 'Animation Metrics',
      'real_time_metrics': 'Real-time Performance Metrics',
      'fps': 'FPS',
      'frame_time': 'Frame Time',
      'animation_time': 'Animation Time',
      'total_duration': 'Total Duration',
      'current_time': 'Current Time',
      'progress': 'Progress',
      'playback_rate': 'Playback Rate',
      'is_playing': 'Playing',
      'repeat_count': 'Repeat Count',
      'play': 'Play',
      'pause': 'Pause',
      'reset': 'Reset',
      'restart': 'Restart',
      'rotation': 'Rotation',
      'translation': 'Translation',
      'scale': 'Scale',
      'skew_x': 'Skew X',
      'skew_y': 'Skew Y',
      'opacity': 'Opacity',
      'color_change': 'Color Change',
      'combined': 'Combined',
      'path_morphing': 'Path Morphing',
      'square_to_circle': 'Square ↔ Circle',
      'star_to_heart': 'Star ↔ Heart',
      'triangle_to_hexagon': 'Triangle ↔ Hexagon',
      'from_shape': 'From',
      'to_shape': 'To',
      'morphing_progress': 'Morphing',
      'smil_animations': 'SMIL Animations',
      'metrics': 'Metrics',
      'rotation_desc': 'Rectangle rotating 360° around center',
      'translation_desc': 'Circle moving from left to right',
      'scale_desc': 'Rectangle scaling from 1x to 2x',
      'skew_x_desc': 'Rectangle skewing horizontally',
      'skew_y_desc': 'Rectangle skewing vertically',
      'opacity_desc': 'Fading in and out',
      'color_change_desc': 'Color transition from red to blue',
      'combined_desc': 'Multiple transforms combined',
      'path_morphing_desc': 'Smooth shape morphing using path interpolation',
    },
    'ru': {
      'app_title': 'Flutter SVG Animations',
      'language': 'Language',
      'switch_language': 'Switch to Russian',
      'welcome_title': 'Welcome to Flutter SVG Animations',
      'welcome_subtitle': 'SMIL Animation Examples with Real-time Metrics',
      'view_examples': 'View Examples',
      'view_metrics': 'View Metrics',
      'examples_title': 'Animation Examples',
      'basic_animations': 'Basic Animations',
      'transform_animations': 'Transformations',
      'color_animations': 'Color Animations',
      'path_animations': 'Path Animations',
      'metrics_title': 'Animation Metrics',
      'real_time_metrics': 'Real-time Performance Metrics',
      'fps': 'FPS',
      'frame_time': 'Frame Time',
      'animation_time': 'Animation Time',
      'total_duration': 'Total Duration',
      'current_time': 'Current Time',
      'progress': 'Progress',
      'playback_rate': 'Playback Rate',
      'is_playing': 'Playing',
      'repeat_count': 'Repeat Count',
      'play': 'Play',
      'pause': 'Pause',
      'reset': 'Reset',
      'restart': 'Restart',
      'rotation': 'Rotation',
      'translation': 'Translation',
      'scale': 'Scale',
      'skew_x': 'Skew X',
      'skew_y': 'Skew Y',
      'opacity': 'Opacity',
      'color_change': 'Color Change',
      'combined': 'Combined',
      'path_morphing': 'Path Morphing',
      'square_to_circle': 'Square ↔ Circle',
      'star_to_heart': 'Star ↔ Heart',
      'triangle_to_hexagon': 'Triangle ↔ Hexagon',
      'from_shape': 'From',
      'to_shape': 'To',
      'morphing_progress': 'Morphing',
      'smil_animations': 'SMIL Animations',
      'metrics': 'Metrics',
      'rotation_desc': 'Rectangle rotating 360° around center',
      'translation_desc': 'Circle moving from left to right',
      'scale_desc': 'Rectangle scaling from 1x to 2x',
      'skew_x_desc': 'Rectangle skewing horizontally',
      'skew_y_desc': 'Rectangle skewing vertically',
      'opacity_desc': 'Fading in and out',
      'color_change_desc': 'Color transition from red to blue',
      'combined_desc': 'Multiple transforms combined',
      'path_morphing_desc': 'Smooth shape morphing using path interpolation',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ru'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
