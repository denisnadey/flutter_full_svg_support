import 'package:flutter/material.dart';

/// Simple state manager for AnimatedSvgPicture examples
class AppState extends ChangeNotifier {
  // AnimatedSvgPicture parameters
  double _width = 300;
  double _height = 300;
  BoxFit _fit = BoxFit.contain;
  Alignment _alignment = Alignment.center;
  Color? _backgroundColor;
  double _playbackRate = 1.0;
  bool _autoPlay = true;
  Duration? _initialTime;

  // Rendering parameters
  bool _clipToViewBox = true;

  // UI parameters
  bool _showFPS = false;
  bool _showParameters = true;
  int _selectedExampleIndex = 0;

  // Getters
  double get width => _width;
  double get height => _height;
  BoxFit get fit => _fit;
  Alignment get alignment => _alignment;
  Color? get backgroundColor => _backgroundColor;
  double get playbackRate => _playbackRate;
  bool get autoPlay => _autoPlay;
  Duration? get initialTime => _initialTime;
  bool get clipToViewBox => _clipToViewBox;
  bool get showFPS => _showFPS;
  bool get showParameters => _showParameters;
  int get selectedExampleIndex => _selectedExampleIndex;

  // Setters
  void setWidth(double value) {
    if (_width != value) {
      _width = value;
      notifyListeners();
    }
  }

  void setHeight(double value) {
    if (_height != value) {
      _height = value;
      notifyListeners();
    }
  }

  void setFit(BoxFit value) {
    if (_fit != value) {
      _fit = value;
      notifyListeners();
    }
  }

  void setAlignment(Alignment value) {
    if (_alignment != value) {
      _alignment = value;
      notifyListeners();
    }
  }

  void setBackgroundColor(Color? value) {
    if (_backgroundColor != value) {
      _backgroundColor = value;
      notifyListeners();
    }
  }

  void setPlaybackRate(double value) {
    if (_playbackRate != value) {
      _playbackRate = value.clamp(0.1, 5.0);
      notifyListeners();
    }
  }

  void setAutoPlay(bool value) {
    if (_autoPlay != value) {
      _autoPlay = value;
      notifyListeners();
    }
  }

  void setInitialTime(Duration? value) {
    if (_initialTime != value) {
      _initialTime = value;
      notifyListeners();
    }
  }

  void setClipToViewBox(bool value) {
    if (_clipToViewBox != value) {
      _clipToViewBox = value;
      notifyListeners();
    }
  }

  void toggleFPS() {
    _showFPS = !_showFPS;
    notifyListeners();
  }

  void toggleParameters() {
    _showParameters = !_showParameters;
    notifyListeners();
  }

  void setSelectedExample(int index) {
    if (_selectedExampleIndex != index) {
      _selectedExampleIndex = index;
      notifyListeners();
    }
  }

  void resetToDefaults() {
    _width = 300;
    _height = 300;
    _fit = BoxFit.contain;
    _alignment = Alignment.center;
    _backgroundColor = null;
    _playbackRate = 1.0;
    _autoPlay = true;
    _initialTime = null;
    _clipToViewBox = true;
    notifyListeners();
  }
}
