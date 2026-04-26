/// CSS custom properties storage for SVG nodes.
part of 'css_variables_calc.dart';

/// CSS custom property store attached to an SvgNode.
/// Custom properties are inheritable by default.
class CssCustomProperties {
  CssCustomProperties([Map<String, String>? initial])
    : _properties = initial ?? {};

  final Map<String, String> _properties;

  /// Get a custom property value from this store.
  String? get(String name) => _properties[name];

  /// Set a custom property value.
  void set(String name, String value) {
    _properties[name] = value;
  }

  /// Check if a property exists.
  bool has(String name) => _properties.containsKey(name);

  /// Get all properties.
  Map<String, String> get all => Map.unmodifiable(_properties);

  /// Create a copy of this store.
  CssCustomProperties copy() => CssCustomProperties(Map.from(_properties));

  @override
  String toString() => 'CssCustomProperties($_properties)';
}

/// Extension to store custom properties on SvgNode.
/// Uses a weak map pattern via attribute storage.
extension SvgNodeCssVariablesExtension on SvgNode {
  static const String _customPropertiesKey = '__cssCustomProperties';

  /// Get or create the custom properties store for this node.
  CssCustomProperties get cssCustomProperties {
    final existing = attributes[_customPropertiesKey];
    if (existing != null && existing.baseValue is CssCustomProperties) {
      return existing.baseValue as CssCustomProperties;
    }
    final store = CssCustomProperties();
    setAttribute(_customPropertiesKey, store);
    return store;
  }

  /// Set custom properties from a parsed style string.
  void parseAndSetCustomProperties(String styleString) {
    final matches = _customPropertyDeclarationRegex.allMatches(styleString);
    for (final match in matches) {
      final name = match.group(1)!.trim();
      final value = match.group(2)!.trim();
      cssCustomProperties.set(name, value);
    }
  }
}
