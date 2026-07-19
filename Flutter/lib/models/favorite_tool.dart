/// A favorite tool as returned by `GET /api/v1/tools/favorite`.
///
/// Backend row shape: `{ tool_slug, category, created_at }`.
class FavoriteTool {
  const FavoriteTool({
    required this.toolSlug,
    this.category,
    this.toolName,
    this.createdAt,
  });

  final String toolSlug;
  final String? category;
  final String? toolName;
  final DateTime? createdAt;

  factory FavoriteTool.fromApi(Map<String, dynamic> json) {
    final created = json['created_at']?.toString();
    return FavoriteTool(
      toolSlug: (json['tool_slug'] ?? json['toolSlug'] ?? '').toString(),
      category: json['category']?.toString(),
      toolName: json['tool_name']?.toString(),
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }

  Map<String, dynamic> toJson() => {
        'tool_slug': toolSlug,
        'category': category,
        'tool_name': toolName,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is FavoriteTool && other.toolSlug == toolSlug;

  @override
  int get hashCode => toolSlug.hashCode;
}
