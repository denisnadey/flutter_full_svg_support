#!/usr/bin/env python3
"""
SVG Feature Coverage Verification Script

Scans SVG files in example/assets/ and test/ directories to audit
which SVG features are being used across the test suite.
"""

import os
import re
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


# SVG elements to track
SVG_ELEMENTS = {
    'rect', 'circle', 'path', 'text', 'use', 'symbol', 'defs', 'g',
    'clipPath', 'mask', 'filter', 'linearGradient', 'radialGradient',
    'pattern', 'marker', 'foreignObject', 'image', 'a', 'view',
    'animate', 'animateTransform', 'animateMotion', 'set', 'stop',
    'feGaussianBlur', 'feOffset', 'feFlood', 'feBlend', 'feComposite',
    'feMorphology', 'feDisplacementMap', 'feImage', 'feConvolveMatrix',
    'feTurbulence', 'feComponentTransfer', 'feDiffuseLighting',
    'feSpecularLighting', 'feMerge', 'feMergeNode', 'feTile',
    'feDropShadow', 'feColorMatrix', 'tspan', 'textPath',
    # Additional common elements
    'svg', 'line', 'ellipse', 'polygon', 'polyline', 'switch',
    'title', 'desc', 'metadata', 'style', 'script',
    'feFuncR', 'feFuncG', 'feFuncB', 'feFuncA',
    'fePointLight', 'feSpotLight', 'feDistantLight',
}

# Key attributes to track
KEY_ATTRIBUTES = {
    'clip-path', 'mask', 'filter', 'transform', 'viewBox',
    'preserveAspectRatio', 'gradientUnits', 'patternUnits',
    'clipPathUnits', 'maskUnits', 'opacity', 'fill-opacity',
    'stroke-opacity', 'font-family', 'letter-spacing', 'text-anchor',
    'writing-mode', 'gradientTransform', 'patternTransform',
    'spreadMethod', 'xlink:href', 'href',
}

# CSS features to detect in <style> blocks
CSS_FEATURES = {
    '@keyframes': r'@keyframes\s+\w+',
    'animation': r'animation\s*:',
    'transition': r'transition\s*:',
    '@font-face': r'@font-face\s*\{',
    'var()': r'var\s*\(',
    'calc()': r'calc\s*\(',
    '@media': r'@media\s+',
    '@import': r'@import\s+',
}

# SMIL attributes
SMIL_ATTRIBUTES = {
    'begin', 'dur', 'repeatCount', 'values', 'keyTimes', 'keySplines',
    'calcMode', 'additive', 'accumulate', 'from', 'to', 'by',
    'attributeName', 'attributeType', 'fill', 'restart', 'min', 'max',
    'repeatDur', 'end', 'keyPoints', 'rotate', 'type', 'path',
}

# SVG namespace prefixes
SVG_NAMESPACES = {
    'svg': 'http://www.w3.org/2000/svg',
    'xlink': 'http://www.w3.org/1999/xlink',
}


def strip_namespace(tag):
    """Remove namespace prefix from tag name."""
    if '}' in tag:
        return tag.split('}')[1]
    return tag


def find_svg_files(directories):
    """Recursively find all SVG files in given directories."""
    svg_files = []
    for directory in directories:
        if not os.path.exists(directory):
            continue
        for root, _, files in os.walk(directory):
            for f in files:
                if f.lower().endswith('.svg'):
                    svg_files.append(os.path.join(root, f))
    return sorted(svg_files)


def extract_style_content(root):
    """Extract all style content from SVG, handling CDATA."""
    style_content = []

    # Find all style elements
    for elem in root.iter():
        tag = strip_namespace(elem.tag)
        if tag == 'style':
            if elem.text:
                # Handle CDATA - ElementTree already extracts the content
                content = elem.text
                # Remove CDATA markers if present in text
                content = re.sub(r'<!\[CDATA\[', '', content)
                content = re.sub(r'\]\]>', '', content)
                style_content.append(content)

    return '\n'.join(style_content)


def detect_css_features(style_content):
    """Detect CSS features in style content."""
    found_features = set()

    for feature_name, pattern in CSS_FEATURES.items():
        if re.search(pattern, style_content, re.IGNORECASE):
            found_features.add(feature_name)

    return found_features


def analyze_svg_file(filepath):
    """Analyze a single SVG file and extract feature usage."""
    result = {
        'elements': set(),
        'attributes': set(),
        'css_features': set(),
        'smil_features': set(),
        'special_features': set(),
        'error': None,
    }

    try:
        # Read file content for raw analysis
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read()

        # Parse XML
        try:
            root = ET.fromstring(content)
        except ET.ParseError as e:
            result['error'] = f"Parse error: {e}"
            return result

        # Analyze all elements
        for elem in root.iter():
            tag = strip_namespace(elem.tag)

            # Track element usage
            if tag.lower() in {e.lower() for e in SVG_ELEMENTS}:
                # Use the canonical name
                for canonical in SVG_ELEMENTS:
                    if canonical.lower() == tag.lower():
                        result['elements'].add(canonical)
                        break
            else:
                # Unknown element, still track it
                result['elements'].add(tag)

            # Analyze attributes
            for attr, value in elem.attrib.items():
                attr_name = strip_namespace(attr)

                # Check for url() references in fill/stroke
                if attr_name in ('fill', 'stroke'):
                    if 'url(' in value:
                        result['attributes'].add(f'{attr_name} url()')

                # Check key attributes
                if attr_name in KEY_ATTRIBUTES:
                    result['attributes'].add(attr_name)

                # Check for xlink:href or href
                if attr_name == 'href' or attr.endswith('}href'):
                    result['attributes'].add('href')

                # Check SMIL attributes
                if attr_name in SMIL_ATTRIBUTES:
                    result['smil_features'].add(attr_name)

                # Detect special values
                if attr_name == 'gradientUnits' and value == 'userSpaceOnUse':
                    result['special_features'].add('userSpaceOnUse')
                if attr_name == 'transform' and len(value.split(')')) > 2:
                    result['special_features'].add('compound transforms')

        # Analyze style content
        style_content = extract_style_content(root)
        if style_content:
            result['css_features'] = detect_css_features(style_content)

        # Also check for inline style attributes with CSS features
        for elem in root.iter():
            style_attr = elem.attrib.get('style', '')
            if style_attr:
                inline_css = detect_css_features(style_attr)
                result['css_features'].update(inline_css)

        # Detect SMIL animation elements
        smil_elements = {'animate', 'animateTransform', 'animateMotion', 'set',
                         'animateColor'}
        for elem in root.iter():
            tag = strip_namespace(elem.tag)
            if tag in smil_elements:
                result['smil_features'].add(tag)

    except Exception as e:
        result['error'] = str(e)

    return result


def scan_dart_tests(test_dir):
    """Scan Dart test files for feature test coverage."""
    test_coverage = defaultdict(list)

    animation_test_dir = os.path.join(test_dir, 'animation')
    if not os.path.exists(animation_test_dir):
        return test_coverage

    for root, _, files in os.walk(animation_test_dir):
        for f in files:
            if f.endswith('.dart'):
                filepath = os.path.join(root, f)
                try:
                    with open(filepath, 'r', encoding='utf-8') as file:
                        content = file.read()

                    # Find test groups and descriptions
                    group_matches = re.findall(
                        r"group\s*\(\s*['\"]([^'\"]+)['\"]",
                        content
                    )
                    test_matches = re.findall(
                        r"test(?:Widgets)?\s*\(\s*['\"]([^'\"]+)['\"]",
                        content
                    )

                    rel_path = os.path.relpath(filepath, test_dir)
                    for match in group_matches + test_matches:
                        test_coverage[rel_path].append(match)

                except Exception:
                    continue

    return test_coverage


def generate_report(results, base_dir, test_coverage):
    """Generate the coverage report."""
    print("=" * 60)
    print("=== SVG Feature Coverage Report ===")
    print("=" * 60)
    print()

    # Count files
    successful = [r for r in results if not r['error']]
    failed = [r for r in results if r['error']]

    print(f"Files scanned: {len(results)}")
    print(f"Successfully parsed: {len(successful)}")
    if failed:
        print(f"Parse errors: {len(failed)}")
    print()

    # Aggregate element usage
    element_usage = defaultdict(set)
    attribute_usage = defaultdict(set)
    css_usage = defaultdict(set)
    smil_usage = defaultdict(set)

    for result in results:
        if result['error']:
            continue

        rel_path = os.path.relpath(result['filepath'], base_dir)

        for elem in result['elements']:
            element_usage[elem].add(rel_path)

        for attr in result['attributes']:
            attribute_usage[attr].add(rel_path)

        for css in result['css_features']:
            css_usage[css].add(rel_path)

        for smil in result['smil_features']:
            smil_usage[smil].add(rel_path)

    # Print Element Usage
    print("-" * 40)
    print("--- Element Usage ---")
    print("-" * 40)
    for elem in sorted(element_usage.keys(), key=lambda x: (-len(element_usage[x]), x)):
        print(f"  {elem}: {len(element_usage[elem])} files")
    print()

    # Print Attribute Usage
    print("-" * 40)
    print("--- Attribute Usage ---")
    print("-" * 40)
    for attr in sorted(attribute_usage.keys(), key=lambda x: (-len(attribute_usage[x]), x)):
        print(f"  {attr}: {len(attribute_usage[attr])} files")
    print()

    # Print CSS Features
    print("-" * 40)
    print("--- CSS Features ---")
    print("-" * 40)
    if css_usage:
        for css in sorted(css_usage.keys(), key=lambda x: (-len(css_usage[x]), x)):
            print(f"  {css}: {len(css_usage[css])} files")
    else:
        print("  (none detected)")
    print()

    # Print SMIL Features
    print("-" * 40)
    print("--- SMIL Features ---")
    print("-" * 40)
    if smil_usage:
        for smil in sorted(smil_usage.keys(), key=lambda x: (-len(smil_usage[x]), x)):
            print(f"  {smil}: {len(smil_usage[smil])} files")
    else:
        print("  (none detected)")
    print()

    # Print test coverage summary
    if test_coverage:
        print("-" * 40)
        print("--- Dart Test Coverage ---")
        print("-" * 40)
        for test_file in sorted(test_coverage.keys()):
            tests = test_coverage[test_file]
            print(f"  {test_file}: {len(tests)} tests/groups")
        print()

    # Print Per-file Details
    print("-" * 40)
    print("--- Per-file Details ---")
    print("-" * 40)

    for result in sorted(results, key=lambda x: x['filepath']):
        rel_path = os.path.relpath(result['filepath'], base_dir)
        print(f"\n{rel_path}:")

        if result['error']:
            print(f"  ERROR: {result['error']}")
            continue

        if result['elements']:
            elements_str = ', '.join(sorted(result['elements']))
            print(f"  Elements: {elements_str}")

        if result['attributes']:
            attrs_str = ', '.join(sorted(result['attributes']))
            print(f"  Attributes: {attrs_str}")

        if result['css_features']:
            css_str = ', '.join(sorted(result['css_features']))
            print(f"  CSS: {css_str}")

        if result['smil_features']:
            smil_str = ', '.join(sorted(result['smil_features']))
            print(f"  SMIL: {smil_str}")

        if result['special_features']:
            special_str = ', '.join(sorted(result['special_features']))
            print(f"  Features: {special_str}")

    # Print files with errors at the end
    if failed:
        print()
        print("-" * 40)
        print("--- Files with Parse Errors ---")
        print("-" * 40)
        for result in failed:
            rel_path = os.path.relpath(result['filepath'], base_dir)
            print(f"  {rel_path}: {result['error']}")


def main():
    """Main entry point."""
    # Determine base directory (project root)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    base_dir = os.path.dirname(script_dir)  # Go up from tool/ to project root

    # Directories to scan
    scan_dirs = [
        os.path.join(base_dir, 'example', 'assets'),
        os.path.join(base_dir, 'test'),
    ]

    print(f"Scanning directories:")
    for d in scan_dirs:
        exists = "✓" if os.path.exists(d) else "✗"
        print(f"  {exists} {d}")
    print()

    # Find all SVG files
    svg_files = find_svg_files(scan_dirs)
    print(f"Found {len(svg_files)} SVG files")
    print()

    # Analyze each file
    results = []
    for filepath in svg_files:
        result = analyze_svg_file(filepath)
        result['filepath'] = filepath
        results.append(result)

    # Scan Dart tests
    test_dir = os.path.join(base_dir, 'test')
    test_coverage = scan_dart_tests(test_dir)

    # Generate report
    generate_report(results, base_dir, test_coverage)


if __name__ == '__main__':
    main()
