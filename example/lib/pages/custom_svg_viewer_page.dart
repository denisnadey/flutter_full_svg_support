import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:full_svg_flutter/src/animation.dart';

import '../playground/playground_analyzer.dart';
import '../playground/playground_models.dart';
import '../playground/playground_trace_store.dart';

enum _ProblemsGrouping { none, code, category }

/// SVG Playground page.
///
/// Allows loading custom SVG, validating structure, rendering animation,
/// collecting runtime trace logs and reviewing a system checklist.
class CustomSvgViewerPage extends StatefulWidget {
  const CustomSvgViewerPage({
    super.key,
    this.initialSvgSource,
    this.initialCaseName,
  });

  final String? initialSvgSource;
  final String? initialCaseName;

  @override
  State<CustomSvgViewerPage> createState() => _CustomSvgViewerPageState();
}

class _CustomSvgViewerPageState extends State<CustomSvgViewerPage>
    with TickerProviderStateMixin {
  final TextEditingController _svgController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _logSearchController = TextEditingController();
  final AnimatedSvgController _animationController = AnimatedSvgController();
  final PlaygroundAnalyzer _analyzer = const PlaygroundAnalyzer();
  final PlaygroundTraceStore _traceStore = PlaygroundTraceStore();

  late final TabController _inputTabController;
  late final TabController _diagnosticsTabController;

  String? _currentSvg;
  PlaygroundReport? _report;
  int _runId = 0;

  bool _isLoadingUrl = false;
  bool _autoPlay = true;
  bool _traceFrameTicks = false;
  double _playbackRate = 1.0;
  double _svgSize = 320;
  Set<SvgTraceLevel> _enabledLogLevels = <SvgTraceLevel>{
    ...SvgTraceLevel.values,
  };
  String _logCategoryFilter = 'all';
  _ProblemsGrouping _problemsGrouping = _ProblemsGrouping.code;

  static const String _circleTemplate = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <circle cx="100" cy="100" r="40" fill="#FF5722">
    <animate attributeName="r" from="40" to="80" dur="2s" repeatCount="indefinite" />
  </circle>
</svg>''';

  static const String _rotatingSquareTemplate = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect x="75" y="75" width="50" height="50" fill="#2196F3">
    <animateTransform attributeName="transform" type="rotate"
      from="0 100 100" to="360 100 100" dur="3s" repeatCount="indefinite" />
  </rect>
</svg>''';

  static const String _eventTemplate = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 200">
  <rect id="target" x="20" y="70" width="120" height="60" rx="10" fill="#42A5F5" />
  <rect id="moving" x="180" y="80" width="70" height="40" fill="#FF7043">
    <animate attributeName="x" begin="target.click" dur="500ms" fill="freeze" values="180;120" />
  </rect>
  <text x="80" y="105" font-size="14" text-anchor="middle" fill="white">click me</text>
</svg>''';

  @override
  void initState() {
    super.initState();
    _inputTabController = TabController(length: 2, vsync: this);
    _diagnosticsTabController = TabController(length: 3, vsync: this);

    final initialSvgSource = widget.initialSvgSource;
    if (initialSvgSource != null && initialSvgSource.trim().isNotEmpty) {
      _svgController.text = initialSvgSource;
      final caseName = widget.initialCaseName;
      final origin = caseName == null ? 'init:external' : 'init:w3c:$caseName';
      _runSvgFromCode(origin: origin);
      return;
    }

    _svgController.text = _eventTemplate;
    _runSvgFromCode(origin: 'init');
  }

  @override
  void dispose() {
    _svgController.dispose();
    _urlController.dispose();
    _logSearchController.dispose();
    _inputTabController.dispose();
    _diagnosticsTabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _svgController.text = data!.text!;
      _appendLog(
        level: SvgTraceLevel.info,
        category: 'input',
        message: 'SVG source pasted from clipboard',
      );
    }
  }

  void _loadTemplate(String templateName, String template) {
    _svgController.text = template;
    _runSvgFromCode(origin: 'template:$templateName');
  }

  Future<void> _loadAssetTemplate(String templateName, String assetPath) async {
    try {
      final template = await rootBundle.loadString(assetPath);
      _loadTemplate(templateName, template);
    } catch (error, stackTrace) {
      _appendLog(
        level: SvgTraceLevel.error,
        category: 'input',
        message: 'Failed to load template asset',
        data: <String, Object?>{'template': templateName, 'asset': assetPath},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _clearAll() {
    setState(() {
      _svgController.clear();
      _urlController.clear();
      _logSearchController.clear();
      _currentSvg = null;
      _report = null;
      _traceStore.clear();
      _enabledLogLevels = <SvgTraceLevel>{...SvgTraceLevel.values};
      _logCategoryFilter = 'all';
      _problemsGrouping = _ProblemsGrouping.code;
    });
  }

  Future<void> _copyCurrentReport() async {
    final report = _report;
    if (report == null) {
      _appendLog(
        level: SvgTraceLevel.warning,
        category: 'export',
        message: 'No report to export',
      );
      return;
    }

    final payload = <String, Object?>{
      'exportedAt': DateTime.now().toIso8601String(),
      'runId': _runId,
      'svgSource': _svgController.text,
      'report': report.toJson(),
      'runtimeIssues': _traceStore.runtimeIssues
          .map((issue) => issue.toJson())
          .toList(growable: false),
      'traceLogs': _traceStore.logs
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
    const encoder = JsonEncoder.withIndent('  ');

    await Clipboard.setData(ClipboardData(text: encoder.convert(payload)));
    _appendLog(
      level: SvgTraceLevel.info,
      category: 'export',
      message: 'Report copied to clipboard',
      data: <String, Object?>{
        'runId': _runId,
        'issueCount': _traceStore.runtimeIssues.length + report.issues.length,
        'logCount': _traceStore.logs.length,
      },
    );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagnostics report copied to clipboard as JSON'),
      ),
    );
  }

  Future<void> _importReportFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim();
    if (raw == null || raw.isEmpty) {
      _appendLog(
        level: SvgTraceLevel.warning,
        category: 'import',
        message: 'Clipboard is empty',
      );
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('JSON root must be an object');
      }
      final payload = _toStringKeyMap(decoded);

      final reportRaw = payload['report'];
      if (reportRaw is! Map) {
        throw const FormatException(
          'Missing "report" object in imported payload',
        );
      }
      final report = PlaygroundReport.fromJson(_toStringKeyMap(reportRaw));
      final svgSource = _asString(payload['svgSource']) ?? '';
      final importedRunId = _asInt(payload['runId']);

      final runtimeIssues = <PlaygroundIssue>[];
      final runtimeIssuesRaw = payload['runtimeIssues'];
      if (runtimeIssuesRaw is Iterable) {
        for (final item in runtimeIssuesRaw) {
          if (item is Map) {
            runtimeIssues.add(PlaygroundIssue.fromJson(_toStringKeyMap(item)));
          }
        }
      }

      final logs = <PlaygroundLogEntry>[];
      final logsRaw = payload['traceLogs'];
      if (logsRaw is Iterable) {
        for (final item in logsRaw) {
          if (item is Map) {
            logs.add(PlaygroundLogEntry.fromJson(_toStringKeyMap(item)));
          }
        }
      }

      setState(() {
        _runId = importedRunId + 1;
        _svgController.text = svgSource;
        _report = report;
        _traceStore.restore(logs: logs, runtimeIssues: runtimeIssues);
        _currentSvg = report.canRender && svgSource.trim().isNotEmpty
            ? svgSource
            : null;
        _inputTabController.index = 0;
        _diagnosticsTabController.index = 0;
        _enabledLogLevels = <SvgTraceLevel>{...SvgTraceLevel.values};
        _logCategoryFilter = 'all';
        _logSearchController.clear();
      });

      _appendLog(
        level: SvgTraceLevel.info,
        category: 'import',
        message: 'Report imported from clipboard',
        data: <String, Object?>{
          'runId': importedRunId,
          'issueCount': report.issues.length + runtimeIssues.length,
          'logCount': logs.length,
        },
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics report imported from clipboard'),
        ),
      );
    } catch (error, stackTrace) {
      _appendLog(
        level: SvgTraceLevel.error,
        category: 'import',
        message: 'Failed to import report JSON',
        error: error,
        stackTrace: stackTrace,
      );
      _appendRuntimeIssue(
        PlaygroundIssue(
          code: 'import.invalid_report',
          category: 'import',
          severity: PlaygroundIssueSeverity.error,
          title: 'Invalid report payload',
          details: '$error',
        ),
      );
    }
  }

  void _syncExternalController() {
    _animationController.setPlaybackRate(_playbackRate);
    if (_autoPlay) {
      _animationController.resume();
    } else {
      _animationController.pause();
    }
  }

  void _runSvgFromCode({String origin = 'code'}) {
    final source = _svgController.text.trim();
    if (source.isEmpty) {
      final issue = const PlaygroundIssue(
        code: 'input.empty_source',
        category: 'input',
        severity: PlaygroundIssueSeverity.error,
        title: 'SVG source is empty',
        details: 'Insert SVG markup before running diagnostics.',
      );
      setState(() {
        _report = PlaygroundReport.empty(issue);
        _currentSvg = null;
      });
      _appendLog(
        level: SvgTraceLevel.error,
        category: 'input',
        message: issue.title,
        data: <String, Object?>{'origin': origin},
      );
      return;
    }

    _runWithSource(source, origin: origin);
  }

  Future<void> _runSvgFromUrl() async {
    final url = _urlController.text.trim();
    final uri = Uri.tryParse(url);

    if (uri == null || !(uri.hasScheme && uri.host.isNotEmpty)) {
      _appendLog(
        level: SvgTraceLevel.error,
        category: 'input',
        message: 'Invalid URL for SVG fetch',
        data: <String, Object?>{'url': url},
      );
      return;
    }

    setState(() {
      _isLoadingUrl = true;
    });

    _appendLog(
      level: SvgTraceLevel.info,
      category: 'network',
      message: 'Fetching SVG from URL',
      data: <String, Object?>{'url': url},
    );

    try {
      final bundle = NetworkAssetBundle(uri);
      final source = await bundle.loadString('');

      _svgController.text = source;
      _inputTabController.index = 0;
      _runWithSource(source, origin: 'url:$url');
    } catch (error, stackTrace) {
      _appendLog(
        level: SvgTraceLevel.error,
        category: 'network',
        message: 'Failed to fetch SVG from URL',
        data: <String, Object?>{'url': url},
        error: error,
        stackTrace: stackTrace,
      );

      _appendRuntimeIssue(
        PlaygroundIssue(
          code: 'network.fetch_failed',
          category: 'network',
          severity: PlaygroundIssueSeverity.error,
          title: 'URL loading failed',
          details: '$error',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUrl = false;
        });
      }
    }
  }

  void _runWithSource(String source, {required String origin}) {
    final report = _analyzer.analyze(source);

    _appendLog(
      level: SvgTraceLevel.info,
      category: 'run',
      message: 'Playground run started',
      data: <String, Object?>{'origin': origin, 'sourceLength': source.length},
    );

    for (final issue in report.issues) {
      _appendLog(
        level: issue.severity.toTraceLevel(),
        category: 'diagnostic',
        message: issue.title,
        data: <String, Object?>{'details': issue.details},
      );
    }

    setState(() {
      _runId += 1;
      _report = report;
      _traceStore.clearRuntimeIssues();
      _currentSvg = report.canRender ? source : null;
    });

    if (report.canRender) {
      _syncExternalController();
      _animationController.restart();
      if (!_autoPlay) {
        _animationController.pause();
      }

      _appendLog(
        level: SvgTraceLevel.info,
        category: 'run',
        message: 'Playground run completed',
        data: <String, Object?>{
          'parseTimeMs': report.parseTimeMs,
          'animationCount': report.animationCount,
          'eventConditionCount': report.eventConditionCount,
        },
      );
    } else {
      _diagnosticsTabController.index = 1;
      _appendLog(
        level: SvgTraceLevel.error,
        category: 'run',
        message: 'Run aborted due to parse/analyze errors',
      );
    }
  }

  void _handleTraceEvent(SvgTraceEvent event) {
    _traceStore.appendTraceEvent(event);
    _runSafeSetState(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _appendRuntimeIssue(PlaygroundIssue issue) {
    void update() {
      if (!mounted) return;
      _traceStore.appendRuntimeIssue(issue);
      setState(() {});
    }

    _runSafeSetState(update);
  }

  void _appendLog({
    required SvgTraceLevel level,
    required String category,
    required String message,
    Map<String, Object?> data = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _traceStore.appendLog(
      level: level,
      category: category,
      message: message,
      data: data,
      error: error,
      stackTrace: stackTrace,
    );

    void update() {
      if (!mounted) return;
      setState(() {});
    }

    _runSafeSetState(update);
  }

  void _runSafeSetState(VoidCallback callback) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      callback();
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      callback();
    });
  }

  List<_ChecklistItem> _buildChecklistItems() {
    final report = _report;
    final hasSource = _svgController.text.trim().isNotEmpty;
    final parseOk = report?.parseSuccess ?? false;
    final rootOk = report?.rootTag == 'svg';
    final viewBoxOk = report?.hasViewBox ?? false;
    final animationsOk = report == null
        ? false
        : (!report.hasAnimationMarkers || report.animationCount > 0);
    final eventTargetsOk = report == null
        ? false
        : report.missingEventTargets.isEmpty;
    final runtimeOk = _traceStore.runtimeIssues.isEmpty;
    final traceAlive = _traceStore.logs.any(
      (log) =>
          log.category == 'event' ||
          log.category == 'controller' ||
          log.category == 'timeline',
    );

    return <_ChecklistItem>[
      _ChecklistItem(
        title: 'SVG source provided',
        ok: hasSource,
        details: hasSource
            ? 'Input is not empty.'
            : 'Paste or type SVG source.',
      ),
      _ChecklistItem(
        title: 'SVG parsing',
        ok: parseOk,
        details: parseOk
            ? 'Parsed in ${report?.parseTimeMs ?? 0} ms.'
            : (report?.parseError ?? 'No parsed document available.'),
      ),
      _ChecklistItem(
        title: 'Root node is <svg>',
        ok: rootOk,
        details: report?.rootTag == null
            ? 'No document root detected.'
            : 'Root: <${report?.rootTag}>',
      ),
      _ChecklistItem(
        title: 'viewBox configured',
        ok: viewBoxOk,
        details: viewBoxOk
            ? 'viewBox found.'
            : 'Recommended for predictable scaling and hit-testing.',
      ),
      _ChecklistItem(
        title: 'Animation extraction',
        ok: animationsOk,
        details: report == null
            ? 'Run diagnostics first.'
            : 'Animation markers: ${report.hasAnimationMarkers}, parsed: ${report.animationCount}',
      ),
      _ChecklistItem(
        title: 'Event targets resolvable',
        ok: eventTargetsOk,
        details: eventTargetsOk
            ? 'All event target IDs exist in SVG.'
            : 'Missing IDs: ${report?.missingEventTargets.join(', ') ?? '-'}',
      ),
      _ChecklistItem(
        title: 'Controller connected',
        ok: _currentSvg != null,
        details: _currentSvg != null
            ? 'AnimatedSvgController is attached to preview widget.'
            : 'No active preview instance.',
      ),
      _ChecklistItem(
        title: 'Runtime error free',
        ok: runtimeOk,
        details: runtimeOk
            ? 'No runtime errors captured in trace stream.'
            : '${_traceStore.runtimeIssues.length} runtime issue(s) captured.',
      ),
      _ChecklistItem(
        title: 'Parity: unsupported tags',
        ok: report == null || report.unsupportedTags.isEmpty,
        details: report == null
            ? 'Run diagnostics first.'
            : (report.unsupportedTags.isEmpty
                  ? 'No unsupported high-impact tags detected.'
                  : _sortedCsv(report.unsupportedTags)),
      ),
      _ChecklistItem(
        title: 'Parity: unsupported filter primitives',
        ok: report == null || report.unsupportedFilterPrimitives.isEmpty,
        details: report == null
            ? 'Run diagnostics first.'
            : (report.unsupportedFilterPrimitives.isEmpty
                  ? 'No unsupported filter primitives detected.'
                  : _sortedCsv(report.unsupportedFilterPrimitives)),
      ),
      _ChecklistItem(
        title: 'References integrity',
        ok: report == null || report.brokenReferences.isEmpty,
        details: report == null
            ? 'Run diagnostics first.'
            : (report.brokenReferences.isEmpty
                  ? 'No broken references found.'
                  : '${report.brokenReferences.length} broken reference(s)'),
      ),
      _ChecklistItem(
        title: 'Trace stream active',
        ok: traceAlive,
        details: traceAlive
            ? 'Timeline/controller/event traces are being captured.'
            : 'Interact with preview to collect event traces.',
      ),
    ];
  }

  Color _levelColor(BuildContext context, SvgTraceLevel level) {
    switch (level) {
      case SvgTraceLevel.debug:
        return Theme.of(context).colorScheme.outline;
      case SvgTraceLevel.info:
        return Colors.blue;
      case SvgTraceLevel.warning:
        return Colors.orange;
      case SvgTraceLevel.error:
        return Colors.red;
    }
  }

  IconData _levelIcon(SvgTraceLevel level) {
    switch (level) {
      case SvgTraceLevel.debug:
        return Icons.bug_report_outlined;
      case SvgTraceLevel.info:
        return Icons.info_outline;
      case SvgTraceLevel.warning:
        return Icons.warning_amber_rounded;
      case SvgTraceLevel.error:
        return Icons.error_outline;
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    final millis = dateTime.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$millis';
  }

  String _formatData(Map<String, Object?> data) {
    if (data.isEmpty) {
      return '-';
    }
    return data.entries.map((e) => '${e.key}=${e.value}').join(', ');
  }

  String _sortedCsv(Set<String> values) {
    final list = values.toList()..sort();
    return list.join(', ');
  }

  Map<String, Object?> _toStringKeyMap(Map<dynamic, dynamic> value) {
    final map = <String, Object?>{};
    for (final entry in value.entries) {
      map[entry.key.toString()] = entry.value;
    }
    return map;
  }

  String? _asString(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    return value.toString();
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialCaseName == null
              ? 'SVG Playground'
              : 'SVG Playground - ${widget.initialCaseName}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.clear_all),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 16),
          child: Column(
            children: [
              _buildInputCard(isMobile),
              const SizedBox(height: 12),
              Expanded(
                child: isMobile
                    ? Column(
                        children: [
                          Expanded(flex: 5, child: _buildPreviewCard()),
                          const SizedBox(height: 12),
                          Expanded(flex: 5, child: _buildDiagnosticsCard()),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 5, child: _buildPreviewCard()),
                          const SizedBox(width: 12),
                          Expanded(flex: 4, child: _buildDiagnosticsCard()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(bool isMobile) {
    return Card(
      child: Column(
        children: [
          TabBar(
            controller: _inputTabController,
            tabs: const [
              Tab(icon: Icon(Icons.code), text: 'SVG code'),
              Tab(icon: Icon(Icons.link), text: 'URL'),
            ],
          ),
          SizedBox(
            height: isMobile ? 240 : 280,
            child: TabBarView(
              controller: _inputTabController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _svgController,
                          expands: true,
                          maxLines: null,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Paste SVG markup here...',
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _runSvgFromCode,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Run diagnostics'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pasteFromClipboard,
                            icon: const Icon(Icons.paste),
                            label: const Text('Paste'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _loadTemplate('pulse-circle', _circleTemplate),
                            icon: const Icon(Icons.circle),
                            label: const Text('Template: Pulse'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _loadTemplate(
                              'rotate-square',
                              _rotatingSquareTemplate,
                            ),
                            icon: const Icon(Icons.crop_square),
                            label: const Text('Template: Rotate'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _loadTemplate('event-click', _eventTemplate),
                            icon: const Icon(Icons.ads_click),
                            label: const Text('Template: Event'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _loadAssetTemplate(
                              'helmet',
                              'assets/astronaut_helmet.svg',
                            ),
                            icon: const Icon(Icons.rocket_launch),
                            label: const Text('Template: Helmet'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _loadAssetTemplate(
                              'coins',
                              'assets/helmet.svg',
                            ),
                            icon: const Icon(Icons.monetization_on),
                            label: const Text('Template: Coins'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'SVG URL',
                          hintText: 'https://example.com/file.svg',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoadingUrl ? null : _runSvgFromUrl,
                        icon: _isLoadingUrl
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text(
                          _isLoadingUrl
                              ? 'Loading...'
                              : 'Fetch and run diagnostics',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: remote loading depends on network policy/CORS for your platform.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_outlined),
                const SizedBox(width: 8),
                Text('Preview', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (_report != null)
                  Chip(
                    label: Text(_report!.canRender ? 'Ready' : 'Invalid'),
                    backgroundColor: _report!.canRender
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      const Text('Size'),
                      Expanded(
                        child: Slider(
                          value: _svgSize,
                          min: 120,
                          max: 540,
                          divisions: 42,
                          label: '${_svgSize.toInt()}px',
                          onChanged: (value) {
                            setState(() {
                              _svgSize = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      const Text('Speed'),
                      Expanded(
                        child: Slider(
                          value: _playbackRate,
                          min: 0.25,
                          max: 2.0,
                          divisions: 7,
                          label: '${_playbackRate.toStringAsFixed(2)}x',
                          onChanged: (value) {
                            setState(() {
                              _playbackRate = value;
                            });
                            _syncExternalController();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Auto play'),
                    Switch(
                      value: _autoPlay,
                      onChanged: (value) {
                        setState(() {
                          _autoPlay = value;
                        });
                        _syncExternalController();
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Trace ticks'),
                    Switch(
                      value: _traceFrameTicks,
                      onChanged: (value) {
                        setState(() {
                          _traceFrameTicks = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    _animationController.resume();
                    setState(() {});
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _animationController.pause();
                    setState(() {});
                  },
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _animationController.restart();
                    setState(() {});
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Restart'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _animationController.toggleDirection();
                    setState(() {});
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(
                    _animationController.isReversed ? 'Reverse' : 'Forward',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: _currentSvg == null
                      ? const _EmptyPreview()
                      : AnimatedSvgPicture.string(
                          _currentSvg!,
                          key: ValueKey('playground-run-$_runId'),
                          width: _svgSize,
                          height: _svgSize,
                          autoPlay: _autoPlay,
                          playbackRate: _playbackRate,
                          controller: _animationController,
                          onTrace: _handleTraceEvent,
                          traceFrameTicks: _traceFrameTicks,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard() {
    final checklist = _buildChecklistItems();
    final checklistDone = checklist.where((item) => item.ok).length;
    final issues = <PlaygroundIssue>[
      ...?_report?.issues,
      ..._traceStore.runtimeIssues,
    ];

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined),
                const SizedBox(width: 8),
                Text(
                  'Diagnostics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Chip(
                  label: Text('Checklist: $checklistDone/${checklist.length}'),
                ),
                const SizedBox(width: 8),
                Chip(label: Text('Problems: ${issues.length}')),
                IconButton(
                  tooltip: 'Import report JSON from clipboard',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: _importReportFromClipboard,
                ),
                IconButton(
                  tooltip: 'Copy report JSON to clipboard',
                  icon: const Icon(Icons.copy_all),
                  onPressed: _report == null ? null : _copyCurrentReport,
                ),
              ],
            ),
          ),
          TabBar(
            controller: _diagnosticsTabController,
            tabs: const [
              Tab(icon: Icon(Icons.route), text: 'Trace Logs'),
              Tab(icon: Icon(Icons.report_problem_outlined), text: 'Problems'),
              Tab(icon: Icon(Icons.checklist_rtl), text: 'Checklist'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _diagnosticsTabController,
              children: [
                _buildLogsTab(),
                _buildProblemsTab(issues),
                _buildChecklistTab(checklist),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab() {
    final logs = _traceStore.logs;
    final categories = logs.map((entry) => entry.category).toSet().toList()
      ..sort();
    final selectedCategory = categories.contains(_logCategoryFilter)
        ? _logCategoryFilter
        : 'all';
    final query = _logSearchController.text.trim().toLowerCase();

    final filteredLogs = logs
        .where((entry) {
          if (!_enabledLogLevels.contains(entry.level)) {
            return false;
          }
          if (selectedCategory != 'all' && entry.category != selectedCategory) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return _logEntryMatchesQuery(entry, query);
        })
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _logSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        isDense: true,
                        hintText: 'Search logs...',
                        suffixIcon: _logSearchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _logSearchController.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: selectedCategory,
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: 'all',
                        child: Text('All categories'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _logCategoryFilter = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: SvgTraceLevel.values
                    .map(
                      (level) => FilterChip(
                        selected: _enabledLogLevels.contains(level),
                        label: Text(level.name),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _enabledLogLevels.add(level);
                            } else if (_enabledLogLevels.length > 1) {
                              _enabledLogLevels.remove(level);
                            }
                          });
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filteredLogs.isEmpty
              ? const Center(child: Text('No logs match the current filters.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = filteredLogs[index];
                    final color = _levelColor(context, entry.level);

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _levelIcon(entry.level),
                                  size: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '[${_formatTime(entry.timestamp)}] ${entry.category}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(entry.message),
                            if (entry.data.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatData(entry.data),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (entry.error != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                entry.error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                            if (entry.stackTrace != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                entry.stackTrace!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProblemsTab(List<PlaygroundIssue> issues) {
    if (issues.isEmpty) {
      return const Center(
        child: Text('No problems detected. System checks look good.'),
      );
    }

    final groupedIssues = _groupIssues(issues, _problemsGrouping);
    final groupKeys = groupedIssues.keys.toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              const Text('Group by:'),
              const SizedBox(width: 8),
              DropdownButton<_ProblemsGrouping>(
                value: _problemsGrouping,
                items: const [
                  DropdownMenuItem(
                    value: _ProblemsGrouping.none,
                    child: Text('none'),
                  ),
                  DropdownMenuItem(
                    value: _ProblemsGrouping.code,
                    child: Text('code'),
                  ),
                  DropdownMenuItem(
                    value: _ProblemsGrouping.category,
                    child: Text('category'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _problemsGrouping = value;
                  });
                },
              ),
              const Spacer(),
              Text('Groups: ${groupKeys.length}'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: groupKeys.length,
            itemBuilder: (context, index) {
              final key = groupKeys[index];
              final entries = groupedIssues[key]!;
              final headerColor = Theme.of(context).colorScheme.primary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: headerColor.withValues(alpha: 0.08),
                        border: Border.all(
                          color: headerColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        '$key (${entries.length})',
                        style: TextStyle(
                          color: headerColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...entries.map(_buildProblemCard),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistTab(List<_ChecklistItem> checklist) {
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: checklist.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = checklist[index];
        final color = item.ok ? Colors.green : Colors.orange;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: ListTile(
            leading: Icon(
              item.ok
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              color: color,
            ),
            title: Text(item.title),
            subtitle: Text(item.details),
          ),
        );
      },
    );
  }

  Color _issueSeverityColor(PlaygroundIssueSeverity severity) {
    switch (severity) {
      case PlaygroundIssueSeverity.info:
        return Colors.blue;
      case PlaygroundIssueSeverity.warning:
        return Colors.orange;
      case PlaygroundIssueSeverity.error:
        return Colors.red;
    }
  }

  IconData _issueSeverityIcon(PlaygroundIssueSeverity severity) {
    switch (severity) {
      case PlaygroundIssueSeverity.info:
        return Icons.info_outline;
      case PlaygroundIssueSeverity.warning:
        return Icons.warning_amber_rounded;
      case PlaygroundIssueSeverity.error:
        return Icons.error_outline;
    }
  }

  String _formatIssueDetails(PlaygroundIssue issue) {
    final metadata = <String>[];
    if (issue.code.isNotEmpty) {
      metadata.add(issue.code);
    }
    if (issue.category.isNotEmpty) {
      metadata.add(issue.category);
    }
    if (issue.tag != null && issue.tag!.isNotEmpty) {
      metadata.add('tag=${issue.tag}');
    }
    if (issue.nodeId != null && issue.nodeId!.isNotEmpty) {
      metadata.add('id=${issue.nodeId}');
    }

    if (metadata.isEmpty) {
      return issue.details;
    }
    return '[${metadata.join(' | ')}]\n${issue.details}';
  }

  bool _logEntryMatchesQuery(PlaygroundLogEntry entry, String query) {
    if (entry.category.toLowerCase().contains(query) ||
        entry.message.toLowerCase().contains(query)) {
      return true;
    }

    if (entry.error?.toLowerCase().contains(query) ?? false) {
      return true;
    }

    if (entry.stackTrace?.toLowerCase().contains(query) ?? false) {
      return true;
    }

    for (final pair in entry.data.entries) {
      if (pair.key.toLowerCase().contains(query) ||
          (pair.value?.toString().toLowerCase().contains(query) ?? false)) {
        return true;
      }
    }

    return false;
  }

  Widget _buildProblemCard(PlaygroundIssue issue) {
    final color = _issueSeverityColor(issue.severity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: ListTile(
          leading: Icon(_issueSeverityIcon(issue.severity), color: color),
          title: Text(issue.title),
          subtitle: Text(_formatIssueDetails(issue)),
        ),
      ),
    );
  }

  Map<String, List<PlaygroundIssue>> _groupIssues(
    List<PlaygroundIssue> issues,
    _ProblemsGrouping grouping,
  ) {
    if (grouping == _ProblemsGrouping.none) {
      return <String, List<PlaygroundIssue>>{'all': issues};
    }

    final result = <String, List<PlaygroundIssue>>{};
    for (final issue in issues) {
      final key = grouping == _ProblemsGrouping.code
          ? issue.code
          : issue.category;
      result.putIfAbsent(key, () => <PlaygroundIssue>[]).add(issue);
    }

    final sortedKeys = result.keys.toList()..sort();
    return <String, List<PlaygroundIssue>>{
      for (final key in sortedKeys) key: result[key]!,
    };
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 10),
          Text(
            'No valid SVG loaded',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Run diagnostics after inserting SVG source.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem {
  const _ChecklistItem({
    required this.title,
    required this.ok,
    required this.details,
  });

  final String title;
  final bool ok;
  final String details;
}
