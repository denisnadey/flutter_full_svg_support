// ignore_for_file: implementation_imports
import 'package:full_svg_flutter/src/animation.dart';
import 'package:full_svg_flutter/src/animation/smil/smil_parser.dart';

import 'playground_models.dart';

/// Static analyzer for SVG playground runs.
class PlaygroundAnalyzer {
  const PlaygroundAnalyzer();

  static const Set<String> _supportedFilterPrimitives = <String>{
    'feGaussianBlur',
    'feOffset',
    'feFlood',
    'feBlend',
    'feComposite',
    'feMerge',
    'feMergeNode',
    'feDropShadow',
    'feColorMatrix',
  };

  // Partial parity map for high-impact Blink gaps.
  static const Set<String> _knownUnsupportedTags = <String>{
    'pattern',
  };

  PlaygroundReport analyze(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return PlaygroundReport.empty(
        const PlaygroundIssue(
          code: 'input.empty_source',
          severity: PlaygroundIssueSeverity.error,
          category: 'input',
          title: 'SVG source is empty',
          details: 'Insert SVG markup before running diagnostics.',
        ),
      );
    }

    final issues = <PlaygroundIssue>[];
    final watch = Stopwatch()..start();

    SvgDocument? document;
    try {
      document = SvgParser.parse(trimmed);
    } catch (error, stackTrace) {
      watch.stop();
      return PlaygroundReport(
        parseSuccess: false,
        canRender: false,
        parseError: '$error',
        parseTimeMs: watch.elapsedMilliseconds,
        rootTag: null,
        hasViewBox: false,
        hasAnimationMarkers: false,
        animationCount: 0,
        eventConditionCount: 0,
        missingEventTargets: const <String>{},
        usedTags: const <String>{},
        unsupportedTags: const <String>{},
        unsupportedFilterPrimitives: const <String>{},
        brokenReferences: const <String>{},
        issues: <PlaygroundIssue>[
          PlaygroundIssue(
            code: 'parse.svg_failed',
            severity: PlaygroundIssueSeverity.error,
            category: 'parse',
            title: 'SVG parsing failed',
            details: '$error\n${_shortStack(stackTrace)}',
          ),
        ],
      );
    }
    watch.stop();

    final rootTag = document.root.tagName;
    final hasViewBox = document.viewBox != null;
    final hasAnimations = AnimationDetector.hasAnimations(trimmed);

    if (rootTag != 'svg') {
      issues.add(
        PlaygroundIssue(
          code: 'parse.root_not_svg',
          severity: PlaygroundIssueSeverity.error,
          category: 'parse',
          title: 'Root element is not <svg>',
          details: 'Renderer expects an <svg> root node.',
          tag: rootTag,
        ),
      );
    }

    if (!hasViewBox) {
      issues.add(
        const PlaygroundIssue(
          code: 'parse.missing_viewbox',
          severity: PlaygroundIssueSeverity.warning,
          category: 'parse',
          title: 'viewBox is missing',
          details: 'Scaling and hit-testing are more predictable with viewBox.',
        ),
      );
    }

    final nodeIds = <String>{};
    final usedTags = <String>{};
    final unsupportedTags = <String>{};
    final unsupportedFilterPrimitives = <String>{};
    final brokenReferences = <String>{};

    _collectNodeIds(document.root, nodeIds);
    _scanNode(
      document.root,
      nodeIds: nodeIds,
      usedTags: usedTags,
      unsupportedTags: unsupportedTags,
      unsupportedFilterPrimitives: unsupportedFilterPrimitives,
      brokenReferences: brokenReferences,
      issues: issues,
    );

    var animationCount = 0;
    var eventConditionCount = 0;
    final missingEventTargets = <String>{};

    if (hasAnimations) {
      try {
        final animations = SmilParser.parseAnimations(document);
        animationCount = animations.length;

        for (final animation in animations) {
          for (final condition in animation.beginConditions) {
            if (condition is! EventCondition) {
              continue;
            }
            eventConditionCount += 1;
            final targetId = condition.targetId;
            if (targetId != null && !nodeIds.contains(targetId)) {
              missingEventTargets.add(targetId);
            }
          }
        }

        if (animations.isEmpty) {
          issues.add(
            const PlaygroundIssue(
              code: 'anim.none_parsed',
              severity: PlaygroundIssueSeverity.warning,
              category: 'animation',
              title: 'Animation tags detected, but no animations parsed',
              details: 'Check <animate>/<animateTransform> attributes.',
            ),
          );
        }
      } catch (error, stackTrace) {
        issues.add(
          PlaygroundIssue(
            code: 'anim.parse_failed',
            severity: PlaygroundIssueSeverity.error,
            category: 'animation',
            title: 'Animation parsing failed',
            details: '$error\n${_shortStack(stackTrace)}',
          ),
        );
      }
    }

    if (missingEventTargets.isNotEmpty) {
      issues.add(
        PlaygroundIssue(
          code: 'event.missing_target',
          severity: PlaygroundIssueSeverity.error,
          category: 'event',
          title: 'Event target IDs not found',
          details: _sortedCsv(missingEventTargets),
        ),
      );
    }

    return PlaygroundReport(
      parseSuccess: true,
      canRender: rootTag == 'svg',
      parseError: null,
      parseTimeMs: watch.elapsedMilliseconds,
      rootTag: rootTag,
      hasViewBox: hasViewBox,
      hasAnimationMarkers: hasAnimations,
      animationCount: animationCount,
      eventConditionCount: eventConditionCount,
      missingEventTargets: missingEventTargets,
      usedTags: usedTags,
      unsupportedTags: unsupportedTags,
      unsupportedFilterPrimitives: unsupportedFilterPrimitives,
      brokenReferences: brokenReferences,
      issues: issues,
    );
  }

  void _collectNodeIds(SvgNode node, Set<String> ids) {
    final id = node.id;
    if (id != null && id.isNotEmpty) {
      ids.add(id);
    }
    for (final child in node.children) {
      _collectNodeIds(child, ids);
    }
  }

  void _scanNode(
    SvgNode node, {
    required Set<String> nodeIds,
    required Set<String> usedTags,
    required Set<String> unsupportedTags,
    required Set<String> unsupportedFilterPrimitives,
    required Set<String> brokenReferences,
    required List<PlaygroundIssue> issues,
  }) {
    usedTags.add(node.tagName);

    if (_knownUnsupportedTags.contains(node.tagName) &&
        unsupportedTags.add(node.tagName)) {
      issues.add(
        PlaygroundIssue(
          code: 'parity.unsupported_tag',
          severity: PlaygroundIssueSeverity.warning,
          category: 'parity',
          title: 'Tag is outside current animated-pipeline support',
          details: '<${node.tagName}> is not fully supported in this pipeline.',
          nodeId: node.id,
          tag: node.tagName,
        ),
      );
    }

    if (node.tagName.startsWith('fe') &&
        !_supportedFilterPrimitives.contains(node.tagName) &&
        unsupportedFilterPrimitives.add(node.tagName)) {
      issues.add(
        PlaygroundIssue(
          code: 'parity.unsupported_filter_primitive',
          severity: PlaygroundIssueSeverity.warning,
          category: 'parity',
          title: 'Filter primitive is not supported',
          details:
              '<${node.tagName}> is not implemented in animated filter pipeline.',
          nodeId: node.id,
          tag: node.tagName,
        ),
      );
    }

    _validateNodeReferences(
      node,
      nodeIds: nodeIds,
      brokenReferences: brokenReferences,
      issues: issues,
    );

    for (final child in node.children) {
      _scanNode(
        child,
        nodeIds: nodeIds,
        usedTags: usedTags,
        unsupportedTags: unsupportedTags,
        unsupportedFilterPrimitives: unsupportedFilterPrimitives,
        brokenReferences: brokenReferences,
        issues: issues,
      );
    }
  }

  void _validateNodeReferences(
    SvgNode node, {
    required Set<String> nodeIds,
    required Set<String> brokenReferences,
    required List<PlaygroundIssue> issues,
  }) {
    const refAttributes = <String>[
      'href',
      'xlink:href',
      'clip-path',
      'mask',
      'filter',
      'fill',
      'stroke',
    ];

    for (final attr in refAttributes) {
      final value = node.getAttributeValue(attr)?.toString();
      if (value == null || value.isEmpty) {
        continue;
      }

      final refs = _extractReferenceIds(attr, value);
      if (refs.isEmpty) {
        continue;
      }

      for (final refId in refs) {
        if (nodeIds.contains(refId)) {
          continue;
        }
        final key = '${node.id ?? node.tagName}|$attr|$refId';
        if (!brokenReferences.add(key)) {
          continue;
        }

        issues.add(
          PlaygroundIssue(
            code: 'refs.missing_target',
            severity: PlaygroundIssueSeverity.error,
            category: 'reference',
            title: 'Broken reference',
            details: '$attr points to missing id "$refId".',
            nodeId: node.id,
            tag: node.tagName,
          ),
        );
      }
    }
  }

  Set<String> _extractReferenceIds(String attribute, String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return const <String>{};
    }

    if ((attribute == 'href' || attribute == 'xlink:href') &&
        value.startsWith('#') &&
        value.length > 1) {
      return <String>{value.substring(1)};
    }

    final matches = RegExp(
      r'''url\(\s*['"]?#([^'"\)\s]+)['"]?\s*\)''',
      caseSensitive: false,
    ).allMatches(value);

    final refs = <String>{};
    for (final match in matches) {
      final id = match.group(1);
      if (id != null && id.isNotEmpty) {
        refs.add(id);
      }
    }
    return refs;
  }

  String _shortStack(StackTrace stackTrace) {
    return stackTrace.toString().split('\n').take(4).join('\n');
  }

  String _sortedCsv(Set<String> values) {
    final list = values.toList()..sort();
    return list.join(', ');
  }
}
