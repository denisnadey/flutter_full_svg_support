part of 'svg_parser.dart';

/// Parses filters from <defs><filter> elements
SvgFilters _parseFilters(XmlElement svgElement) {
  final filters = SvgFilters();

  // Collect all <filter> elements in the document, regardless of location.
  // Some W3C fixtures define filters directly under <g> instead of inside
  // <defs>, and those filters are still valid paint servers.
  final filterElements = svgElement.findAllElements('filter');
  if (filterElements.isEmpty) {
    return filters;
  }

  for (final filterElement in filterElements) {
    final filterId = filterElement.getAttribute('id');
    if (filterId == null || filterId.isEmpty) {
      continue; // A filter without an ID cannot be referenced
    }

    // Parse filter region (x, y, width, height) for output clipping.
    // Per SVG spec, default is -10%, -10%, 120%, 120% (objectBoundingBox).
    final filterRegion = _parseFilterRegion(filterElement);
    filters.setFilterRegion(filterId, filterRegion);

    // Parse filter primitives (feGaussianBlur, feDropShadow, etc.)
    for (final child in filterElement.childElements) {
      final filter = _parseFilterPrimitive(child, filterId);
      if (filter != null) {
        filters.add(filter);
      }
    }
  }

  return filters;
}

/// Parses a filter primitive (feGaussianBlur, feDropShadow, feColorMatrix)
SvgFilter? _parseFilterPrimitive(XmlElement element, String filterId) {
  final tagName = element.name.local;

  switch (tagName) {
    case 'feGaussianBlur':
      return _parseGaussianBlur(element, filterId);
    case 'feMorphology':
      return _parseMorphology(element, filterId);
    case 'feDisplacementMap':
      return _parseDisplacementMap(element, filterId);
    case 'feImage':
      return _parseFeImage(element, filterId);
    case 'feConvolveMatrix':
      return _parseConvolveMatrix(element, filterId);
    case 'feTurbulence':
      return _parseTurbulence(element, filterId);
    case 'feComponentTransfer':
      return _parseComponentTransfer(element, filterId);
    case 'feDiffuseLighting':
      return _parseDiffuseLighting(element, filterId);
    case 'feSpecularLighting':
      return _parseSpecularLighting(element, filterId);
    case 'feOffset':
      return _parseOffset(element, filterId);
    case 'feFlood':
      return _parseFlood(element, filterId);
    case 'feBlend':
      return _parseBlend(element, filterId);
    case 'feComposite':
      return _parseComposite(element, filterId);
    case 'feMerge':
      return _parseMerge(element, filterId);
    case 'feTile':
      return _parseTile(element, filterId);
    case 'feDropShadow':
      return _parseDropShadow(element, filterId);
    case 'feColorMatrix':
      return _parseColorMatrix(element, filterId);
    default:
      // Other filters are not yet supported
      return null;
  }
}

/// Set of recognized filter primitive tag names.
const Set<String> _filterPrimitiveTags = {
  'feGaussianBlur',
  'feMorphology',
  'feDisplacementMap',
  'feImage',
  'feConvolveMatrix',
  'feTurbulence',
  'feComponentTransfer',
  'feDiffuseLighting',
  'feSpecularLighting',
  'feOffset',
  'feFlood',
  'feBlend',
  'feComposite',
  'feMerge',
  'feTile',
  'feDropShadow',
  'feColorMatrix',
};

/// Links filter primitive SvgFilter objects to their corresponding SvgNodes
/// in the DOM tree. This enables filter primitives to read animated attribute
/// values at render time.
///
/// Walks the DOM tree to find <defs><filter><fe*> elements, then matches
/// them positionally to the SvgFilter objects in the filter registry.
void _linkFilterPrimitivesToNodes(SvgNode root, SvgFilters filters) {
  void visit(SvgNode node) {
    if (node.tagName == 'filter') {
      final filterId = node.id;
      if (filterId != null && filterId.isNotEmpty) {
        final filterPrimitives = filters.getAllById(filterId);
        if (filterPrimitives.isNotEmpty) {
          // Match fe* children to SvgFilter objects by position.
          var primitiveIndex = 0;
          for (final feNode in node.children) {
            if (!_filterPrimitiveTags.contains(feNode.tagName)) continue;
            if (primitiveIndex < filterPrimitives.length) {
              filterPrimitives[primitiveIndex].sourceElement = feNode;
            }
            primitiveIndex++;
          }
        }
      }
    }
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(root);
}

/// Parse filter region attributes (x, y, width, height) from a `<filter>` element.
///
/// Supports both percentage and bare-number syntax.
/// For `filterUnits="objectBoundingBox"` (default), values are fractions (0-1)
/// or percentages. For `filterUnits="userSpaceOnUse"`, values are user coords.
SvgFilterRegion _parseFilterRegion(XmlElement filterElement) {
  final filterUnits = filterElement.getAttribute('filterUnits');
  final isOBB = filterUnits == null || filterUnits == 'objectBoundingBox';

  double parseRegionValue(String? attr, double defaultVal) {
    if (attr == null || attr.trim().isEmpty) return defaultVal;
    final trimmed = attr.trim();
    if (trimmed.endsWith('%')) {
      final v = double.tryParse(trimmed.substring(0, trimmed.length - 1));
      return v != null ? v / 100.0 : defaultVal;
    }
    return double.tryParse(trimmed) ?? defaultVal;
  }

  final x = parseRegionValue(
    filterElement.getAttribute('x'),
    isOBB ? -0.10 : 0.0,
  );
  final y = parseRegionValue(
    filterElement.getAttribute('y'),
    isOBB ? -0.10 : 0.0,
  );
  final w = parseRegionValue(
    filterElement.getAttribute('width'),
    isOBB ? 1.20 : 0.0,
  );
  final h = parseRegionValue(
    filterElement.getAttribute('height'),
    isOBB ? 1.20 : 0.0,
  );

  return SvgFilterRegion(
    x: x,
    y: y,
    width: w,
    height: h,
    isObjectBoundingBox: isOBB,
  );
}
