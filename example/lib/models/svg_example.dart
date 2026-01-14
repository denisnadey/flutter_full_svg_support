import 'package:flutter/material.dart';

/// Модель примера SVG анимации
class SvgExample {
  final String id;
  final String title;
  final String description;
  final String svgContent;
  final IconData icon;
  final String category;
  final List<String> tags;

  const SvgExample({
    required this.id,
    required this.title,
    required this.description,
    required this.svgContent,
    required this.icon,
    required this.category,
    this.tags = const [],
  });
}

/// Категории примеров
class ExampleCategory {
  static const String basic = 'Basic';
  static const String transform = 'Transform';
  static const String color = 'Color';
  static const String path = 'Path';
  static const String motion = 'Motion';
  static const String advanced = 'Advanced';
}
