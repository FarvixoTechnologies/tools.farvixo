import 'package:flutter/material.dart';

enum ToolBadge { popular, isNew, ai }

class ToolCategory {
  const ToolCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

class Tool {
  const Tool({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.icon,
    this.badge,
  });

  final String id;
  final String name;
  final String description;
  final String categoryId;
  final IconData icon;
  final ToolBadge? badge;
}
