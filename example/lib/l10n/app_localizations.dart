import 'package:flutter/material.dart';

/// Класс для локализации приложения
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

  // Общие
  String get appTitle => _localizedStrings[locale.languageCode]!['app_title']!;
  String get language => _localizedStrings[locale.languageCode]!['language']!;
  String get switchLanguage =>
      _localizedStrings[locale.languageCode]!['switch_language']!;

  // Главная страница
  String get welcomeTitle =>
      _localizedStrings[locale.languageCode]!['welcome_title']!;
  String get welcomeSubtitle =>
      _localizedStrings[locale.languageCode]!['welcome_subtitle']!;
  String get viewExamples =>
      _localizedStrings[locale.languageCode]!['view_examples']!;
  String get viewMetrics =>
      _localizedStrings[locale.languageCode]!['view_metrics']!;

  // Примеры
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

  // Метрики
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

  // Кнопки управления
  String get play => _localizedStrings[locale.languageCode]!['play']!;
  String get pause => _localizedStrings[locale.languageCode]!['pause']!;
  String get reset => _localizedStrings[locale.languageCode]!['reset']!;
  String get restart => _localizedStrings[locale.languageCode]!['restart']!;

  // Примеры анимаций
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

  // Path Morphing
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

  // Описания
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

  // Unified Examples
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
      'app_title': 'Flutter SVG Анимации',
      'language': 'Язык',
      'switch_language': 'Переключить на английский',
      'welcome_title': 'Добро пожаловать в Flutter SVG Анимации',
      'welcome_subtitle':
          'Примеры SMIL анимаций с метриками в реальном времени',
      'view_examples': 'Посмотреть примеры',
      'view_metrics': 'Посмотреть метрики',
      'examples_title': 'Примеры анимаций',
      'basic_animations': 'Базовые анимации',
      'transform_animations': 'Трансформации',
      'color_animations': 'Цветовые анимации',
      'path_animations': 'Анимации путей',
      'metrics_title': 'Метрики анимации',
      'real_time_metrics': 'Метрики производительности в реальном времени',
      'fps': 'FPS',
      'frame_time': 'Время кадра',
      'animation_time': 'Время анимации',
      'total_duration': 'Общая длительность',
      'current_time': 'Текущее время',
      'progress': 'Прогресс',
      'playback_rate': 'Скорость воспроизведения',
      'is_playing': 'Воспроизводится',
      'repeat_count': 'Количество повторов',
      'play': 'Играть',
      'pause': 'Пауза',
      'reset': 'Сброс',
      'restart': 'Перезапуск',
      'rotation': 'Вращение',
      'translation': 'Перемещение',
      'scale': 'Масштабирование',
      'skew_x': 'Наклон X',
      'skew_y': 'Наклон Y',
      'opacity': 'Прозрачность',
      'color_change': 'Смена цвета',
      'combined': 'Комбинированные',
      'path_morphing': 'Морфинг путей',
      'square_to_circle': 'Квадрат ↔ Круг',
      'star_to_heart': 'Звезда ↔ Сердце',
      'triangle_to_hexagon': 'Треугольник ↔ Шестиугольник',
      'from_shape': 'Из',
      'to_shape': 'В',
      'morphing_progress': 'Морфинг',
      'smil_animations': 'SMIL Анимации',
      'metrics': 'Метрики',
      'rotation_desc': 'Прямоугольник вращается на 360° вокруг центра',
      'translation_desc': 'Круг перемещается слева направо',
      'scale_desc': 'Прямоугольник увеличивается от 1x до 2x',
      'skew_x_desc': 'Прямоугольник наклоняется по горизонтали',
      'skew_y_desc': 'Прямоугольник наклоняется по вертикали',
      'opacity_desc': 'Появление и исчезновение',
      'color_change_desc': 'Переход цвета от красного к синему',
      'combined_desc': 'Несколько трансформаций вместе',
      'path_morphing_desc':
          'Плавный морфинг форм с использованием интерполяции путей',
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
