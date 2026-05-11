part of 'animated_svg_picture.dart';

extension _AnimatedSvgPictureStateLifecycleExtension
    on _AnimatedSvgPictureState {
  /// Handles widget updates when configuration changes.
  void _handleWidgetUpdate(AnimatedSvgPicture oldWidget) {
    // Update controller subscription
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerUpdate);
      widget.controller?.addListener(_onControllerUpdate);
    }

    if (widget._svgString != oldWidget._svgString) {
      // SVG changed - full re-initialization
      _dispose();
      _initialize();
    } else if (widget.playbackRate != oldWidget.playbackRate &&
        _timeline != null) {
      // Only the speed changed
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
      // AutoPlay changed
      if (widget.autoPlay && _controller == null && _timeline != null) {
        // Need to create a controller
        final duration = _timeline!.totalDuration;
        _controller = AnimationController(vsync: this, duration: duration);
        _controller!.addListener(_onAnimationTick);
        _isReversed = widget.controller?.isReversed ?? _isReversed;
        _startPlayback();
      } else if (!widget.autoPlay && _controller != null) {
        // Need to remove the controller
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
      // Check for animations
      _hasAnimations = AnimationDetector.hasAnimations(widget._svgString);

      // Parse SVG
      _document = SvgParser.parse(widget._svgString);
      // Wire debug hooks on the controller so external tooling can read
      // live state at any time. Cleared in [_dispose].
      if (widget.controller != null) {
        widget.controller!
          ..debugSnapshotProvider = _captureDebugSnapshot
          ..debugCurrentTimeMsProvider = _debugCurrentTimeMs
          ..debugJsEvaluator =
              (code) => _jsBridge?.evaluateForDebug(code);
      }

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
        // Parse animations
        final animations = SmilParser.parseAnimations(_document);
        _trace(
          category: 'init',
          message: 'Animation scan completed',
          data: <String, Object?>{'animationCount': animations.length},
        );

        if (animations.isNotEmpty) {
          // Create timeline
          _timeline = SvgTimeline(
            animations: animations,
            rootNode: _document.root,
          );
          _timeline!.playbackRate = widget.playbackRate;

          // Initialize the initial animation state (t=0 or initialTime)
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

          // Repaint the first frame (important when autoPlay: false)
          if (mounted) {
            _markNeedsRepaint();
          }

          // Create AnimationController if autoPlay or if there are event-based animations
          // Event-based animations require a ticker to update frames after activation
          final hasEventAnimations = _timeline!.hasEventBasedAnimations();
          if (widget.autoPlay || hasEventAnimations) {
            final duration = _timeline!.totalDuration;

            _controller = AnimationController(vsync: this, duration: duration);
            _isReversed = widget.controller?.isReversed ?? false;

            // Set the initial controller value if initialTime is specified
            if (widget.initialTime != null && duration.inMicroseconds > 0) {
              final progress =
                  widget.initialTime!.inMicroseconds / duration.inMicroseconds;
              _controller!.value = progress.clamp(0.0, 1.0);
            }

            // Listen for controller updates
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
              // For event-driven mode, start the controller in repeat mode
              // so the ticker runs and updates frames after events
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
      // Bootstrap JS bridge if the SVG has inline <script> elements
      final scripts = _document.scripts;
      if (scripts != null && scripts.isNotEmpty) {
        _jsBridge = SvgJsBridge(
          document: _document,
          markNeedsRepaint: _markNeedsRepaint,
          addEventHandler: (elementId, eventType, callback) {
            _SvgEventHandlerRegistry.instance.addHandler(
              elementId,
              eventType,
              (_) => callback(),
            );
          },
        );
        for (final script in scripts) {
          _jsBridge!.executeScript(script);
        }
        // Signal that inline scripts are done; external scripts may still be loading.
        _jsBridge!.onInlinesDone();
        _trace(
          category: 'js',
          message: 'JS scripts executed',
          data: <String, Object?>{'count': scripts.length},
        );
        // Fire load events after all external scripts have been fetched and executed.
        final generation = _imageLoadGeneration;
        unawaited(_jsBridge!.externalScriptsLoaded.then((_) {
          if (!mounted || generation != _imageLoadGeneration) return;
          _jsBridge?.fireLoadEvents();
          _trace(category: 'js', message: 'JS load events fired');
        }));
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

    // Update timeline
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

    // Repaint
    _markNeedsRepaint();
  }

  void _onControllerUpdate() {
    if (_timeline == null) return;

    final controller = widget.controller;
    if (controller == null) return;

    // Handle reverse/forward
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

    // Handle pause/resume
    if (controller.isPaused) {
      _controller?.stop();
      _trace(category: 'controller', message: 'Paused by external controller');
    } else if (_controller != null && !_controller!.isAnimating) {
      _trace(category: 'controller', message: 'Resumed by external controller');
      _startPlayback();
    }

    // Handle playbackRate
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

    // Handle seek
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
    // Clear debug hooks so the controller doesn't hold stale references
    // to a torn-down widget tree.
    if (widget.controller != null) {
      widget.controller!
        ..debugSnapshotProvider = null
        ..debugCurrentTimeMsProvider = null
        ..debugJsEvaluator = null;
    }
    _controller?.removeListener(_onAnimationTick);
    _controller?.dispose();
    _controller = null;
    _timeline = null;
    _hoveredElementId = null;
    _hoveredAnchorInfo = null;
    _jsBridge?.dispose();
    _jsBridge = null;
  }

  // ── Debug snapshot ──────────────────────────────────────────────────────
  //
  // Walks the live SvgDocument tree and produces a JSON-ready map suitable
  // for the debug viewer (gallery card → long-press → inspector). Captures
  // every element's id/tag/depth/attrs as of right now (i.e. *after* SMIL
  // + CSS + JS have written their animated values for the current frame).
  // For elements with their own geometry it also computes a root-space
  // bounding box so the viewer can draw selection outlines and do
  // tap-to-select hit-testing.

  double _debugCurrentTimeMs() {
    final c = _controller;
    final t = _timeline;
    if (c == null || t == null) return 0;
    return c.value * t.totalDuration.inMilliseconds;
  }

  Map<String, Object?> _captureDebugSnapshot() {
    final elements = <Map<String, Object?>>[];
    void walk(SvgNode node, int depth, _M2 parentToRoot) {
      final attrs = <String, String>{};
      for (final entry in node.attributes.entries) {
        final v = entry.value.effectiveValue;
        if (v == null) continue;
        attrs[entry.key] = v.toString();
      }
      // `id` and `class` are stored as dedicated fields, not in attributes.
      if (node.id != null && !attrs.containsKey('id')) attrs['id'] = node.id!;
      if (node.className != null && !attrs.containsKey('class')) {
        attrs['class'] = node.className!;
      }
      // Compose this node's local transform on top of the parent's.
      final local = _parseTransformAttr(attrs['transform']);
      final toRoot = parentToRoot.multiply(local);
      // Local geometric bbox (if any) projected to root.
      Map<String, double>? bboxRoot;
      final local2d = _localGeometryBbox(node);
      if (local2d != null) {
        final corners = <List<double>>[
          [local2d.left, local2d.top],
          [local2d.right, local2d.top],
          [local2d.right, local2d.bottom],
          [local2d.left, local2d.bottom],
        ];
        double minX = double.infinity, minY = double.infinity;
        double maxX = -double.infinity, maxY = -double.infinity;
        for (final c in corners) {
          final p = toRoot.transformPoint(c[0], c[1]);
          if (p[0] < minX) minX = p[0];
          if (p[1] < minY) minY = p[1];
          if (p[0] > maxX) maxX = p[0];
          if (p[1] > maxY) maxY = p[1];
        }
        bboxRoot = <String, double>{
          'x': minX, 'y': minY, 'w': maxX - minX, 'h': maxY - minY,
        };
      }
      elements.add(<String, Object?>{
        'id': node.id,
        'tag': node.tagName,
        'depth': depth,
        'attrs': attrs,
        if (bboxRoot != null) 'bboxRoot': bboxRoot,
        'hasAnimations': node.hasAnimations,
      });
      for (final child in node.children) {
        walk(child, depth + 1, toRoot);
      }
    }
    try {
      walk(_document.root, 0, _M2.identity());
    } catch (_) {
      // Snapshot is best-effort: failures should not crash the host app.
    }
    final vb = _document.viewBox;
    return <String, Object?>{
      'capturedAtMs': _debugCurrentTimeMs(),
      'totalDurationMs': _timeline?.totalDuration.inMilliseconds,
      'isPaused': widget.controller?.isPaused,
      'playbackRate': widget.playbackRate,
      'autoPlay': widget.autoPlay,
      'viewBox': vb == null
          ? null
          : <String, double>{
              'x': vb.left,
              'y': vb.top,
              'width': vb.width,
              'height': vb.height,
            },
      'elementCount': elements.length,
      'elements': elements,
    };
  }

  /// Returns the geometric bbox of [node] in its own local coordinate
  /// space (i.e. *before* its own `transform` is applied), or `null` if
  /// the element has no inherent geometry (groups, defs, etc.).
  Rect? _localGeometryBbox(SvgNode node) {
    double? d(String name) {
      final v = node.getAttributeValue(name);
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }
    switch (node.tagName) {
      case 'rect':
        final x = d('x') ?? 0, y = d('y') ?? 0;
        final w = d('width') ?? 0, h = d('height') ?? 0;
        if (w <= 0 || h <= 0) return null;
        return Rect.fromLTWH(x, y, w, h);
      case 'circle':
        final cx = d('cx') ?? 0, cy = d('cy') ?? 0, r = d('r') ?? 0;
        if (r <= 0) return null;
        return Rect.fromCircle(center: Offset(cx, cy), radius: r);
      case 'ellipse':
        final cx = d('cx') ?? 0, cy = d('cy') ?? 0;
        final rx = d('rx') ?? 0, ry = d('ry') ?? 0;
        if (rx <= 0 || ry <= 0) return null;
        return Rect.fromCenter(
            center: Offset(cx, cy), width: rx * 2, height: ry * 2);
      case 'line':
        final x1 = d('x1') ?? 0, y1 = d('y1') ?? 0;
        final x2 = d('x2') ?? 0, y2 = d('y2') ?? 0;
        return Rect.fromLTRB(
          x1 < x2 ? x1 : x2,
          y1 < y2 ? y1 : y2,
          x1 < x2 ? x2 : x1,
          y1 < y2 ? y2 : y1,
        );
      default:
        return null;
    }
  }

  static final RegExp _translateRe =
      RegExp(r'translate\(\s*(-?\d+\.?\d*)[\s,]+(-?\d+\.?\d*)\s*\)');
  static final RegExp _matrixRe = RegExp(
      r'matrix\(\s*(-?\d+\.?\d*(?:[eE][+\-]?\d+)?)[\s,]+'
      r'(-?\d+\.?\d*(?:[eE][+\-]?\d+)?)[\s,]+'
      r'(-?\d+\.?\d*(?:[eE][+\-]?\d+)?)[\s,]+'
      r'(-?\d+\.?\d*(?:[eE][+\-]?\d+)?)[\s,]+'
      r'(-?\d+\.?\d*(?:[eE][+\-]?\d+)?)[\s,]+'
      r'(-?\d+\.?\d*(?:[eE][+\-]?\d+)?)\s*\)');

  /// Parses a sequence of `translate(...)` / `matrix(...)` transform
  /// functions into a 2D affine matrix. Anything else (rotate/scale/skew)
  /// would require more work; the snapshot is best-effort so unknown
  /// transforms simply fall back to identity. This is good enough for the
  /// bbox overlay since the bulk of authored transforms are translate
  /// and matrix.
  _M2 _parseTransformAttr(String? s) {
    if (s == null || s.isEmpty) return _M2.identity();
    var m = _M2.identity();
    for (final tx in _translateRe.allMatches(s)) {
      final dx = double.tryParse(tx.group(1)!) ?? 0;
      final dy = double.tryParse(tx.group(2)!) ?? 0;
      m = m.multiply(_M2.translate(dx, dy));
    }
    for (final mx in _matrixRe.allMatches(s)) {
      final a = double.tryParse(mx.group(1)!) ?? 1;
      final b = double.tryParse(mx.group(2)!) ?? 0;
      final c = double.tryParse(mx.group(3)!) ?? 0;
      final dd = double.tryParse(mx.group(4)!) ?? 1;
      final e = double.tryParse(mx.group(5)!) ?? 0;
      final f = double.tryParse(mx.group(6)!) ?? 0;
      m = m.multiply(_M2(a, b, c, dd, e, f));
    }
    return m;
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
        clipToViewBox: widget.clipToViewBox,
      ),
      size: Size.infinite,
    );

    // Wrap with gesture detection for event-based animations or link handling
    final needsGestureDetection =
        (_hasAnimations && _timeline != null) ||
        widget.onLinkTap != null ||
        _jsBridge != null;
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

    // Wrap in SizedBox if dimensions are specified
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

  /// Start the animation
  void _play() {
    _controller?.forward();
  }

  /// Stop the animation
  void _pause() {
    _controller?.stop();
  }

  /// Go to the beginning
  void _reset() {
    _controller?.reset();
    _timeline?.reset();
  }

  /// Seek to a specific time
  void _seekTo(Duration time) {
    if (_controller == null || _timeline == null) return;

    final progress =
        time.inMicroseconds / _timeline!.totalDuration.inMicroseconds;
    _controller!.value = progress.clamp(0.0, 1.0);
  }
}

/// 2D affine matrix [a b c d e f] representing `[a c e; b d f; 0 0 1]`,
/// matching SVG's `matrix(...)` order. Used by the debug snapshot pass to
/// project per-element local geometry into root coordinates so the viewer
/// can draw bbox overlays.
class _M2 {
  _M2(this.a, this.b, this.c, this.d, this.e, this.f);
  factory _M2.identity() => _M2(1, 0, 0, 1, 0, 0);
  factory _M2.translate(double dx, double dy) => _M2(1, 0, 0, 1, dx, dy);

  final double a, b, c, d, e, f;

  _M2 multiply(_M2 o) => _M2(
        a * o.a + c * o.b,
        b * o.a + d * o.b,
        a * o.c + c * o.d,
        b * o.c + d * o.d,
        a * o.e + c * o.f + e,
        b * o.e + d * o.f + f,
      );

  List<double> transformPoint(double x, double y) =>
      <double>[a * x + c * y + e, b * x + d * y + f];
}
