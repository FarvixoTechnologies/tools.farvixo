import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ToolBadge { popular, isNew, ai }

/// Parse a backend badge string (`'popular' | 'new' | 'ai'`) into [ToolBadge].
ToolBadge? toolBadgeFromApi(Object? raw) {
  final value = raw?.toString().trim().toLowerCase();
  switch (value) {
    case 'popular':
      return ToolBadge.popular;
    case 'new':
      return ToolBadge.isNew;
    case 'ai':
      return ToolBadge.ai;
    default:
      return null;
  }
}

/// Serialize a [ToolBadge] back to the backend string form.
String? toolBadgeToApi(ToolBadge? badge) {
  switch (badge) {
    case ToolBadge.popular:
      return 'popular';
    case ToolBadge.isNew:
      return 'new';
    case ToolBadge.ai:
      return 'ai';
    case null:
      return null;
  }
}

/// Maps a backend category icon name (lucide-style) to a Material [IconData].
IconData _iconForCategoryName(String? name) {
  switch (name?.trim().toLowerCase()) {
    case 'file-text':
      return Icons.picture_as_pdf_rounded;
    case 'image':
      return Icons.image_rounded;
    case 'video':
      return Icons.play_circle_rounded;
    case 'music':
      return Icons.music_note_rounded;
    case 'bot':
      return Icons.auto_awesome_rounded;
    case 'code':
      return Icons.code_rounded;
    case 'type':
      return Icons.text_fields_rounded;
    case 'search':
      return Icons.search_rounded;
    case 'briefcase':
      return Icons.business_center_rounded;
    case 'share':
      return Icons.share_rounded;
    case 'settings':
      return Icons.build_rounded;
    case 'shield':
      return Icons.shield_rounded;
    case 'calculator':
      return Icons.calculate_rounded;
    case 'repeat':
      return Icons.swap_horiz_rounded;
    case 'landmark':
      return Icons.account_balance_rounded;
    default:
      return Icons.apps_rounded;
  }
}

/// Maps a backend accent token (`accent-pdf`, …) to a theme [Color].
Color _colorForAccent(String? accent) {
  switch (accent?.trim().toLowerCase()) {
    case 'accent-pdf':
      return AppColors.accentPdf;
    case 'accent-image':
      return AppColors.accentImage;
    case 'accent-video':
      return AppColors.accentVideo;
    case 'accent-audio':
      return AppColors.accentAudio;
    case 'accent-ai':
      return AppColors.accentAi;
    case 'accent-dev':
      return AppColors.accentDev;
    case 'accent-text':
      return AppColors.accentText;
    case 'accent-utility':
      return AppColors.accentUtility;
    default:
      return AppColors.accentDev;
  }
}

class ToolCategory {
  const ToolCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.shortName,
    this.description,
    this.toolCount,
  });

  /// Category id — equals the backend `slug`.
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  /// Backend-only enrichment (null for the bundled local catalog).
  final String? shortName;
  final String? description;
  final int? toolCount;

  /// Parse a category from `GET /api/v1/tools/categories`.
  factory ToolCategory.fromApi(Map<String, dynamic> json) {
    return ToolCategory(
      id: (json['slug'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: _iconForCategoryName(json['icon']?.toString()),
      color: _colorForAccent(json['accent']?.toString()),
      shortName: json['shortName']?.toString(),
      description: json['description']?.toString(),
      toolCount: (json['toolCount'] as num?)?.toInt(),
    );
  }
}

class Tool {
  const Tool({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.icon,
    this.badge,
    this.slug,
    this.url,
  });

  /// Stable id — equals the backend `slug` for API-sourced tools.
  final String id;
  final String name;
  final String description;
  final String categoryId;
  final IconData icon;
  final ToolBadge? badge;

  /// Backend-only enrichment (null for the bundled local catalog).
  final String? slug;
  final String? url;

  /// The slug used against the backend (`/api/v1/tools/:slug`, favorites).
  String get remoteSlug => slug ?? id;

  /// Parse a tool from `GET /api/v1/tools` / `/search` / `/:id`.
  ///
  /// The backend does not ship an icon; [fallbackIcon] lets the caller reuse an
  /// icon from the bundled catalog when the slug is known.
  factory Tool.fromApi(
    Map<String, dynamic> json, {
    IconData fallbackIcon = Icons.build_rounded,
  }) {
    final slug = (json['slug'] ?? json['id'] ?? '').toString();
    return Tool(
      id: slug,
      slug: slug,
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      categoryId: (json['category'] ?? json['categoryId'] ?? '').toString(),
      icon: fallbackIcon,
      badge: toolBadgeFromApi(json['badge']),
      url: json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': remoteSlug,
        'name': name,
        'description': description,
        'category': categoryId,
        'badge': toolBadgeToApi(badge),
        'url': url,
      };

  Tool copyWith({IconData? icon}) => Tool(
        id: id,
        name: name,
        description: description,
        categoryId: categoryId,
        icon: icon ?? this.icon,
        badge: badge,
        slug: slug,
        url: url,
      );
}
