part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateLifecycleExtension
    on _AnimatedSvgPictureState {
  /// Handles widget updates when configuration changes.
  void _handleWidgetUpdate(AnimatedSvgPicture oldWidget) {
    // Обновляем подписку на контроллер
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
    }

    if (widget._svgString != oldWidget._svgString) {
      // SVG изменился - полная переинициализация
      _dispose();
      _initialize();
    } else if (widget.playbackRate != oldWidget.playbackRate &&
        _timeline != null) {
      // Только скорость изменилась
      final currentProgress = _controller?.value ?? 0.0;
      _timeline!.playbackRate = widget.playbackRate;
      if (_controller != null) {
        final newMicros =
            (_timeline!.totalDuration.inMicroseconds / widget.playbackRate)
                .round()
                .clamp(1, 0x7fffffffffffffff);
        _controller!.stop();
        _controller!.duration = Duration(microseconds: newMicros);
        _controller!.value = currentProgress;
        _startPlayback();
      }
    } else if (widget.autoPlay != oldWidget.autoPlay) {
      // AutoPlay изменился
      if (widget.autoPlay && _controller == null && _timeline != null) {
        // Нужно создать контроллер
        final duration = _timeline!.totalDuration;
        _controller = AnimationController(vsync: this, duration: duration);
        _controller!.addListener(_onAnimationTick);
        _isReversed = widget.controller?.isReversed ?? _isReversed;
        _startPlayback();
      } else if (!widget.autoPlay && _controller != null) {
        // Нужно удалить контроллер
        _controller?.removeListener(_onAnimationTick);
        _controller?.dispose();
        _controller = null;
      }
    }
  }

  void _initialize() {
    _trace(
      category: 'init',
      message: 'Initializing AnimatedSvgPicture',
      data: <String, Object?>{
        'sourceLength': widget._svgString.length,
        'autoPlay': widget.autoPlay,
        'playbackRate': widget.playbackRate,
        'initialTimeMs': widget.initialTime?.inMilliseconds,
      },
    );

    _imageLoadGeneration++;
    _disposeResolvedImages();

    try {
      // Проверяем наличие анимаций
      _hasAnimations = AnimationDetector.hasAnimations(widget._svgString);

      // Парсим SVG
      _document = SvgParser.parse(widget._svgString);
      _trace(
        category: 'init',
        message: 'SVG parsed successfully',
        data: <String, Object?>{
          'hasAnimations': _hasAnimations,
          'rootTag': _document.root.tagName,
          'rootChildren': _document.root.children.length,
          'viewBox': _document.viewBox?.toString(),
          'viewCount': _document.viewIds.length,
        },
      );

      // Populate available views on controller
      if (widget.controller != null) {
        widget.controller!.availableViews = _document.viewIds.toList();
      }

      _scheduleImagePreload();
      _scheduleFontRegistration();

      if (_hasAnimations) {
        // Парсим анимации
        final animations = SmilParser.parseAnimations(_document);
        _trace(
          category: 'init',
          message: 'Animation scan completed',
          data: <String, Object?>{'animationCount': animations.length},
        );

        if (animations.isNotEmpty) {
          // Создаём timeline
          _timeline = SvgTimeline(
            animations: animations,
            rootNode: _document.root,
          );
          _timeline!.playbackRate = widget.playbackRate;

          // Инициализируем начальное состояние анимаций (t=0 или initialTime)
          final startTime = widget.initialTime ?? Duration.zero;
          _timeline!.seek(startTime);
          _trace(
            category: 'timeline',
            message: 'Timeline initialized',
            data: <String, Object?>{
              'startTimeMs': startTime.inMilliseconds,
              'totalDurationMs': _timeline!.totalDuration.inMilliseconds,
              'activeAnimations': _timeline!.getActiveAnimations().length,
            },
          );

          // Перерисовываем первый кадр (важно для autoPlay: false)
          if (mounted) {
            _markNeedsRepaint();
          }

          // Создаём AnimationController если autoPlay или есть event-based анимации
          // Event-based анимации требуют тикера для обновления кадров после активации
          final hasEventAnimations = _timeline!.hasEventBasedAnimations();
          if (widget.autoPlay || hasEventAnimations) {
            final duration = _timeline!.totalDuration;

            _controller = AnimationController(vsync: this, duration: duration);
            _isReversed = widget.controller?.isReversed ?? false;

            // Устанавливаем начальное значение контроллера если задано initialTime
            if (widget.initialTime != null && duration.inMicroseconds > 0) {
              final progress =
                  widget.initialTime!.inMicroseconds / duration.inMicroseconds;
              _controller!.value = progress.clamp(0.0, 1.0);
            }

            // Слушаем обновления контроллера
            _controller!.addListener(_onAnimationTick);
            _trace(
              category: 'controller',
              message: widget.autoPlay
                  ? 'Animation controller created'
                  : 'Animation controller created for event-driven mode',
              data: <String, Object?>{
                'durationMs': duration.inMilliseconds,
                'initialValue': _controller!.value,
                'isReversed': _isReversed,
                'hasEventAnimations': hasEventAnimations,
              },
            );

            if (widget.autoPlay) {
              _startPlayback();
            } else {
              // Для event-driven режима запускаем контроллер в repeat mode
              // чтобы тикер работал и обновлял кадры после событий
              _controller!.repeat();
              _trace(
                category: 'controller',
                message: 'Event-driven ticker started (repeat mode)',
              );
            }
          } else {
            _trace(
              category: 'controller',
              message: 'Auto play disabled and no event-based animations',
            );
          }
        } else {
          _hasAnimations = false;
          _trace(
            category: 'init',
            level: SvgTraceLevel.warning,
            message: 'Animation markers found, but no parseable animations',
          );
        }
      } else {
        _trace(
          category: 'init',
          message: 'Static SVG detected (no animation tags)',
        );
      }
    } catch (error, stackTrace) {
      _trace(
        category: 'init',
        level: SvgTraceLevel.error,
        message: 'Failed to initialize AnimatedSvgPicture',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  bool _hasInfiniteAnimations() {
    return _timeline?.animations.any((anim) => anim.repeatCount.isInfinite) ??
        false;
  }

  void _startPlayback() {
    if (_controller == null) return;

    if (_hasInfiniteAnimations()) {
      _controller!.stop();
      if (_isReversed && _controller!.value <= _controller!.lowerBound) {
        _controller!.value = _controller!.upperBound;
      } else if (!_isReversed &&
          _controller!.value >= _controller!.upperBound) {
        _controller!.value = _controller!.lowerBound;
      }
      _controller!.repeat(reverse: _isReversed);
      _trace(
        category: 'controller',
        message: 'Playback started in repeat mode',
        data: <String, Object?>{
          'reversed': _isReversed,
          'infinite': true,
          'value': _controller!.value,
        },
      );
      return;
    }

    if (_isReversed) {
      _controller!.reverse(from: _controller!.value);
      _trace(
        category: 'controller',
        message: 'Playback started in reverse mode',
        data: <String, Object?>{'value': _controller!.value},
      );
    } else {
      _controller!.forward(from: _controller!.value);
      _trace(
        category: 'controller',
        message: 'Playback started in forward mode',
        data: <String, Object?>{'value': _controller!.value},
      );
    }
  }

  void _onAnimationTick() {
    if (_controller == null || _timeline == null) return;

    // Map normalized controller value [0,1] to SVG time using totalDuration.
    // controller.duration may be shortened for faster playback, so we always
    // use totalDuration here to get the correct absolute SVG timestamp.
    final elapsed = Duration(
      microseconds:
          (_controller!.value * _timeline!.totalDuration.inMicroseconds)
              .round(),
    );

    // Обновляем timeline
    _timeline!.seek(elapsed);

    if (widget.traceFrameTicks) {
      _trace(
        category: 'tick',
        level: SvgTraceLevel.debug,
        message: 'Frame tick',
        data: <String, Object?>{
          'controllerValue': _controller!.value,
          'elapsedMs': elapsed.inMilliseconds,
          'activeAnimations': _timeline!.getActiveAnimations().length,
        },
      );
    }

    // Перерисовываем
    _markNeedsRepaint();
  }

  void _onControllerUpdate() {
    if (_timeline == null) return;

    final controller = widget.controller;
    if (controller == null) return;

    // Обработка reverse/forward
    if (_isReversed != controller.isReversed) {
      _isReversed = controller.isReversed;
      _trace(
        category: 'controller',
        message: 'Direction changed',
        data: <String, Object?>{'isReversed': _isReversed},
      );
      if (!controller.isPaused && _controller != null) {
        _startPlayback();
      }
    }

    // Обработка pause/resume
    if (controller.isPaused) {
      _controller?.stop();
      _trace(category: 'controller', message: 'Paused by external controller');
    } else if (_controller != null && !_controller!.isAnimating) {
      _trace(category: 'controller', message: 'Resumed by external controller');
      _startPlayback();
    }

    // Обработка playbackRate
    if (controller.playbackRate != _timeline!.playbackRate) {
      final currentProgress = _controller?.value ?? 0.0;
      _timeline!.playbackRate = controller.playbackRate;
      if (_controller != null) {
        final newMicros =
            (_timeline!.totalDuration.inMicroseconds / controller.playbackRate)
                .round()
                .clamp(1, 0x7fffffffffffffff);
        _controller!.stop();
        _controller!.duration = Duration(microseconds: newMicros);
        _controller!.value = currentProgress;
        if (!controller.isPaused) {
          _startPlayback();
        }
      }
      _trace(
        category: 'controller',
        message: 'Playback rate updated',
        data: <String, Object?>{'playbackRate': controller.playbackRate},
      );
    }

    // Обработка seek
    if (controller.pendingSeek != null) {
      final targetTime = controller.pendingSeek!;
      _timeline!.seek(targetTime);

      // Sync controller value using totalDuration (not controller.duration which
      // may be shortened for playback rate).
      if (_controller != null) {
        final totalMicros = _timeline!.totalDuration.inMicroseconds;
        if (totalMicros > 0) {
          final progress = targetTime.inMicroseconds / totalMicros;
          _controller!.value = progress.clamp(0.0, 1.0);
        }
      }

      controller.clearPendingSeek();
      _trace(
        category: 'controller',
        message: 'Seek applied',
        data: <String, Object?>{'targetTimeMs': targetTime.inMilliseconds},
      );
      _markNeedsRepaint();
    }

    // Handle view switching
    if (controller.pendingViewId != null ||
        controller.currentViewId != _document.activeViewId) {
      final viewId = controller.pendingViewId ?? controller.currentViewId;
      final success = _document.switchToView(viewId);
      if (success) {
        _trace(
          category: 'controller',
          message: 'View switched',
          data: <String, Object?>{'viewId': viewId},
        );
      } else {
        _trace(
          category: 'controller',
          level: SvgTraceLevel.warning,
          message: 'View not found',
          data: <String, Object?>{'viewId': viewId},
        );
      }
      controller.clearPendingViewChange();
      _markNeedsRepaint();
    }
  }

  void _dispose() {
    _trace(category: 'lifecycle', message: 'Disposing AnimatedSvgPicture');
    _imageLoadGeneration++;
    _disposeResolvedImages();
    widget.controller?.removeListener(_onControllerUpdate);
    _controller?.removeListener(_onAnimationTick);
    _controller?.dispose();
    _controller = null;
    _timeline = null;
    _hoveredElementId = null;
    _hoveredAnchorInfo = null;
  }

  /// Schedules font registration for embedded @font-face fonts.
  ///
  /// This mirrors the image preload pattern: async work with generation guards.
  void _scheduleFontRegistration() {
    final fontFaceRules = _document.cssFontFaceRules;
    if (fontFaceRules == null || fontFaceRules.isEmpty) {
      return;
    }

    final generation = _imageLoadGeneration;

    _trace(
      category: 'font',
      message: 'Font registration scheduled',
      data: <String, Object?>{'count': fontFaceRules.length},
    );

    unawaited(_registerFontsAndRepaint(generation));
  }

  /// Registers embedded fonts and triggers repaint on success.
  Future<void> _registerFontsAndRepaint(int generation) async {
    try {
      final success = await _document.registerEmbeddedFonts(
        fontLoader: widget.fontLoader,
      );
      if (!mounted || generation != _imageLoadGeneration) {
        return;
      }

      if (success) {
        _trace(
          category: 'font',
          message: 'Font registration completed',
          data: <String, Object?>{
            'registeredFamilies': _document.registeredFontFamilies.toList(),
          },
        );
        _markNeedsRepaint();
      } else {
        _trace(
          category: 'font',
          level: SvgTraceLevel.warning,
          message: 'Font registration completed with errors',
          data: <String, Object?>{'errors': _document.fontRegistrationErrors},
        );
        // Still repaint — some fonts may have loaded successfully
        _markNeedsRepaint();
      }
    } catch (e, stackTrace) {
      // Graceful fallback — font registration failure should not crash rendering
      if (mounted && generation == _imageLoadGeneration) {
        _trace(
          category: 'font',
          level: SvgTraceLevel.error,
          message: 'Font registration failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Builds the widget tree for the animated SVG.
  Widget _buildWidget(BuildContext context) {
    Widget svgWidget = CustomPaint(
      painter: AnimatedSvgPainter(
        document: _document,
        backgroundColor: widget.backgroundColor,
        imagesByHref: _imagesByHref,
        convolvedImagesByFilterKey: _convolvedImagesByFilterKey,
        lightingImagesByFilterKey: _lightingImagesByFilterKey,
        displacementImagesByFilterKey: _displacementImagesByFilterKey,
        animationTime: _timeline == null
            ? null
            : _timeline!.currentTime.inMicroseconds / 1000000.0,
        hasAnimations: _hasAnimations,
      ),
      size: Size.infinite,
    );

    // Wrap with gesture detection for event-based animations or link handling
    final needsGestureDetection =
        (_hasAnimations && _timeline != null) || widget.onLinkTap != null;
    if (needsGestureDetection) {
      svgWidget = Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: GestureDetector(
          onTapDown: (details) => _handleTapDown(details),
          onTapUp: (_) => _handleTapUp(),
          onTapCancel: () => _handleTapUp(),
          onLongPressStart: _handleLongPressStart,
          onLongPressEnd: _handleLongPressEnd,
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          child: MouseRegion(
            cursor: _hoveredAnchorInfo != null
                ? SystemMouseCursors.click
                : MouseCursor.defer,
            onEnter: (event) => _handleMouseEnter(event.localPosition),
            onExit: (_) => _handleMouseExit(),
            onHover: (event) => _handleMouseHover(event.localPosition),
            child: svgWidget,
          ),
        ),
      );
    }

    // Add foreignObject overlay widgets if builder is provided
    if (widget.foreignObjectBuilder != null) {
      svgWidget = _buildWithForeignObjectOverlay(context, svgWidget);
    }

    // Оборачиваем в SizedBox если указаны размеры
    if (widget.width != null || widget.height != null) {
      svgWidget = SizedBox(
        width: widget.width,
        height: widget.height,
        child: svgWidget,
      );
    }

    // Wrap with Semantics for accessibility
    final accessibleName = _document.accessibleName;
    final accessibleDescription = _document.accessibleDescription;
    final accessibleRole = _document.accessibleRole;

    if (accessibleName != null || accessibleDescription != null) {
      svgWidget = Semantics(
        label: accessibleName,
        hint: accessibleDescription,
        image: accessibleRole == 'img',
        button: accessibleRole == 'button',
        link: accessibleRole == 'link',
        excludeSemantics: false,
        child: svgWidget,
      );
    }

    return svgWidget;
  }

  /// Запустить анимацию
  void _play() {
    _controller?.forward();
  }

  /// Остановить анимацию
  void _pause() {
    _controller?.stop();
  }

  /// Перейти к началу
  void _reset() {
    _controller?.reset();
    _timeline?.reset();
  }

  /// Перейти к конкретному времени
  void _seekTo(Duration time) {
    if (_controller == null || _timeline == null) return;

    final progress =
        time.inMicroseconds / _timeline!.totalDuration.inMicroseconds;
    _controller!.value = progress.clamp(0.0, 1.0);
  }
}
