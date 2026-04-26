import 'package:flutter/foundation.dart';

/// Controller for managing AnimatedSvgPicture
///
/// Allows programmatic control of animation playback:
/// - pause/resume
/// - seek to a specific time
/// - changing playback speed
/// - reversing direction
///
/// Example:
/// ```dart
/// final controller = AnimatedSvgController();
///
/// AnimatedSvgPicture.string(
///   svgString,
///   controller: controller,
/// );
///
/// // Later:
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

  /// Is the animation paused?
  bool get isPaused => _isPaused;

  /// Playback speed (1.0 = normal, 2.0 = 2x speed)
  double get playbackRate => _playbackRate;

  /// Is playback in reverse direction?
  bool get isReversed => _isReversed;

  /// Is there a pending seek operation?
  Duration? get pendingSeek => _seekTarget;

  /// Get the pending view ID to switch to.
  String? get pendingViewId => _viewChangeRequested ? _viewId : null;

  /// Current requested view ID (null for default view).
  String? get currentViewId => _viewId;

  /// Pause the animation
  void pause() {
    if (!_isPaused) {
      _isPaused = true;
      notifyListeners();
    }
  }

  /// Resume playback
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

  /// Seek to a specific time
  ///
  /// [time] - target time in the animation
  void seek(Duration time) {
    _seekTarget = time;
    notifyListeners();
  }

  /// Set the playback speed
  ///
  /// [rate] - playback speed
  /// - 1.0 = normal speed
  /// - 2.0 = double speed
  /// - 0.5 = half speed
  /// - Must be positive
  void setPlaybackRate(double rate) {
    if (rate <= 0) {
      throw ArgumentError('Playback rate must be positive, got: $rate');
    }
    if (_playbackRate != rate) {
      _playbackRate = rate;
      notifyListeners();
    }
  }

  /// Play in reverse direction
  void reverse() {
    if (!_isReversed) {
      _isReversed = true;
      notifyListeners();
    }
  }

  /// Play in forward direction
  void forward() {
    if (_isReversed) {
      _isReversed = false;
      notifyListeners();
    }
  }

  /// Toggle playback direction
  void toggleDirection() {
    _isReversed = !_isReversed;
    notifyListeners();
  }

  /// Restart the animation from the beginning
  void restart() {
    _seekTarget = Duration.zero;
    if (_isPaused) {
      _isPaused = false;
    }
    notifyListeners();
  }

  /// Clear the pending seek (called by the widget after processing)
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
