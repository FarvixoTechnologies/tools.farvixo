import '../models/tool_model.dart';

/// Filter chips on the advanced search screen.
enum ToolSearchFilter { all, ai, popular, newTools }

/// One ranked hit from [ToolSearch].
class ToolSearchHit {
  const ToolSearchHit({required this.tool, required this.score});

  final Tool tool;
  final int score;
}

/// Advanced scored tool search — name / description / category / slug /
/// keywords with typo-tolerant token matching and ranking.
class ToolSearch {
  ToolSearch._();

  static const trendingQueries = <String>[
    'PDF to Word',
    'Image Compressor',
    'Background Remover',
    'AI Chat',
    'Compress PDF',
    'QR Code',
    'Video Converter',
    'OCR',
  ];

  /// Ranked search over [catalog]. Empty query → empty list.
  static List<ToolSearchHit> search(
    List<Tool> catalog,
    String query, {
    String? categoryId,
    ToolSearchFilter filter = ToolSearchFilter.all,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final tokens = q
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final hits = <ToolSearchHit>[];
    for (final tool in catalog) {
      if (categoryId != null &&
          categoryId.isNotEmpty &&
          tool.categoryId != categoryId) {
        continue;
      }
      if (!_passesFilter(tool, filter)) continue;

      final score = _score(tool, q, tokens);
      if (score > 0) hits.add(ToolSearchHit(tool: tool, score: score));
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.tool.name.toLowerCase().compareTo(b.tool.name.toLowerCase());
    });
    return hits;
  }

  static List<Tool> searchTools(
    List<Tool> catalog,
    String query, {
    String? categoryId,
    ToolSearchFilter filter = ToolSearchFilter.all,
  }) =>
      search(
        catalog,
        query,
        categoryId: categoryId,
        filter: filter,
      ).map((h) => h.tool).toList();

  /// Merge network results into ranked local hits (local order wins, append new).
  static List<Tool> merge(List<Tool> localRanked, List<Tool> remote) {
    final seen = <String>{};
    final out = <Tool>[];
    for (final t in localRanked) {
      if (seen.add(t.id)) out.add(t);
    }
    for (final t in remote) {
      if (seen.add(t.id)) out.add(t);
    }
    return out;
  }

  static bool _passesFilter(Tool tool, ToolSearchFilter filter) {
    switch (filter) {
      case ToolSearchFilter.all:
        return true;
      case ToolSearchFilter.ai:
        return tool.badge == ToolBadge.ai ||
            tool.categoryId == 'ai' ||
            tool.name.toLowerCase().contains('ai ');
      case ToolSearchFilter.popular:
        return tool.badge == ToolBadge.popular;
      case ToolSearchFilter.newTools:
        return tool.badge == ToolBadge.isNew;
    }
  }

  static int _score(Tool tool, String q, List<String> tokens) {
    final name = tool.name.toLowerCase();
    final desc = tool.description.toLowerCase();
    final cat = tool.categoryId.toLowerCase();
    final slug = (tool.slug ?? tool.id).toLowerCase().replaceAll('-', ' ');
    final keywords = _keywordsFor(tool).join(' ');
    final hay = '$name $desc $cat $slug $keywords';

    var score = 0;

    if (name == q) score += 120;
    if (name.startsWith(q)) score += 60;
    if (name.contains(q)) score += 36;
    if (slug == q || slug.replaceAll(' ', '') == q.replaceAll(' ', '')) {
      score += 50;
    }
    if (keywords.contains(q)) score += 40;
    if (desc.contains(q)) score += 18;
    if (cat.contains(q)) score += 14;

    var tokenHits = 0;
    for (final token in tokens) {
      if (hay.contains(token)) {
        tokenHits++;
        score += 12;
        if (name.contains(token)) score += 8;
        if (keywords.contains(token)) score += 6;
        continue;
      }
      // Light typo tolerance for tokens ≥ 4 chars.
      if (token.length >= 4 && _fuzzyContains(hay, token)) {
        tokenHits++;
        score += 6;
      }
    }

    if (tokens.length > 1 && tokenHits < tokens.length) {
      // Require most tokens for multi-word queries.
      if (tokenHits == 0) return 0;
      if (tokenHits < (tokens.length / 2).ceil()) return 0;
    }

    if (tool.badge == ToolBadge.popular) score += 4;
    if (tool.badge == ToolBadge.ai) score += 2;
    if (tool.badge == ToolBadge.isNew) score += 2;

    return score;
  }

  static List<String> _keywordsFor(Tool tool) {
    final out = <String>[
      for (final k in tool.keywords) k.toLowerCase(),
    ];
    out.addAll(
      tool.name
          .toLowerCase()
          .split(RegExp(r'[\s\-_/]+'))
          .where((w) => w.length > 1),
    );
    out.add(tool.categoryId.toLowerCase());
    out.add(tool.id.toLowerCase().replaceAll('-', ' '));
    return out;
  }

  /// True when [token] is a near-substring of [hay] (1 edit / transposition).
  static bool _fuzzyContains(String hay, String token) {
    if (hay.contains(token)) return true;
    // Sliding window of token length ±1.
    final minLen = token.length - 1;
    final maxLen = token.length + 1;
    for (var len = minLen; len <= maxLen; len++) {
      if (len < 3) continue;
      for (var i = 0; i + len <= hay.length; i++) {
        final slice = hay.substring(i, i + len);
        if (_editDistanceAtMost1(slice, token)) return true;
      }
    }
    return false;
  }

  static bool _editDistanceAtMost1(String a, String b) {
    if (a == b) return true;
    final la = a.length;
    final lb = b.length;
    if ((la - lb).abs() > 1) return false;
    if (la > lb) return _editDistanceAtMost1(b, a);

    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < la && j < lb) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      edits++;
      if (edits > 1) return false;
      if (la == lb) {
        i++;
        j++;
      } else {
        j++; // insertion in a / deletion in b
      }
    }
    if (j < lb || i < la) edits++;
    return edits <= 1;
  }
}
