import 'package:flutter/foundation.dart';

/// Контроллер для управления AnimatedSvgPicture
///
/// Позволяет программно контролировать воспроизведение анимации:
/// - pause/resume
/// - seek к конкретному времени
/// - изменение скорости воспроизведения
/// - реверс направления
///
/// Пример:
/// ```dart
/// final controller = AnimatedSvgController();
///
/// AnimatedSvgPicture.string(
///   svgString,
///   controller: controller,
/// );
///
/// // Позже:
/// controller.pause();
/// controller.seek(Duration(seconds: 2));
/// controller.resume();
/// ```
class AnimatedSvgController extends ChangeNotifier {
  bool _isPaused = false;
  double _playbackRate = 1.0;
  Duration? _seekTarget;
  bool _isReversed = false;
  String? _viewId;
  bool _viewChangeRequested = false;

  /// Анимация на паузе?
  bool get isPaused => _isPaused;

  /// Скорость воспроизведения (1.0 = normal, 2.0 = 2x speed)
  double get playbackRate => _playbackRate;

  /// Воспроизведение в обратном направлении?
  bool get isReversed => _isReversed;

  /// Есть ли pending seek operation?
  Duration? get pendingSeek => _seekTarget;

  /// Get the pending view ID to switch to.
  String? get pendingViewId => _viewChangeRequested ? _viewId : null;

  /// Current requested view ID (null for default view).
  String? get currentViewId => _viewId;

  /// Поставить анимацию на паузу
  void pause() {
    if (!_isPaused) {
      _isPaused = true;
      notifyListeners();
    }
  }

  /// Возобновить воспроизведение
  void resume() {
    if (_isPaused) {
      _isPaused = false;
      notifyListeners();
    }
  }

  /// Toggle pause/resume
  void togglePlayPause() {
    if (_isPaused) {
      resume();
    } else {
      pause();
    }
  }

  /// Перейти к конкретному времени
  ///
  /// [time] - целевое время в анимации
  void seek(Duration time) {
    _seekTarget = time;
    notifyListeners();
  }

  /// Установить скорость воспроизведения
  ///
  /// [rate] - скорость воспроизведения
  /// - 1.0 = нормальная скорость
  /// - 2.0 = удвоенная скорость
  /// - 0.5 = замедленная скорость
  /// - Должна быть положительной
  void setPlaybackRate(double rate) {
    if (rate <= 0) {
      throw ArgumentError('Playback rate must be positive, got: $rate');
    }
    if (_playbackRate != rate) {
      _playbackRate = rate;
      notifyListeners();
    }
  }

  /// Воспроизводить в обратном направлении
  void reverse() {
    if (!_isReversed) {
      _isReversed = true;
      notifyListeners();
    }
  }

  /// Воспроизводить в прямом направлении
  void forward() {
    if (_isReversed) {
      _isReversed = false;
      notifyListeners();
    }
  }

  /// Toggle направление воспроизведения
  void toggleDirection() {
    _isReversed = !_isReversed;
    notifyListeners();
  }

  /// Перезапустить анимацию с начала
  void restart() {
    _seekTarget = Duration.zero;
    if (_isPaused) {
      _isPaused = false;
    }
    notifyListeners();
  }

  /// Очистить pending seek (вызывается виджетом после обработки)
  ///
  /// @nodoc - internal use only
  void clearPendingSeek() {
    _seekTarget = null;
  }

  /// Switch to a specific view by ID.
  ///
  /// Pass null to switch back to the default view (the root SVG's viewBox).
  /// The view must be defined via a <view> element in the SVG.
  void switchToView(String? viewId) {
    _viewId = viewId;
    _viewChangeRequested = true;
    notifyListeners();
  }

  /// Clear the pending view change (called by widget after processing).
  ///
  /// @nodoc - internal use only
  void clearPendingViewChange() {
    _viewChangeRequested = false;
  }

  /// Get available view IDs from the document.
  /// This must be populated by the widget after parsing.
  List<String> availableViews = [];
}
