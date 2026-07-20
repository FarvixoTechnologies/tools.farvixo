import '../models/parsed_qr.dart';
import '../models/qr_type.dart';

/// Offline risk level for a scanned payload. Ordered by severity.
enum RiskLevel { safe, caution, danger }

/// Result of the offline security assessment.
class SecurityVerdict {
  const SecurityVerdict({
    required this.level,
    required this.score,
    required this.confidence,
    required this.reasons,
  });

  /// Overall verdict.
  final RiskLevel level;

  /// 0 (safe) … 100 (dangerous) heuristic risk score.
  final int score;

  /// 0.0–1.0 — how confident the offline heuristics are. Lower for payloads we
  /// can't fully evaluate without a network reputation lookup.
  final double confidence;

  /// Human-readable reasons behind the verdict (empty when clean).
  final List<String> reasons;

  bool get isSafe => level == RiskLevel.safe;
}

/// Pure-Dart, fully-offline URL/payload risk heuristics.
///
/// Ships now with zero API keys. Online reputation (Safe Browsing, VirusTotal)
/// is intentionally out of scope here and would layer on top later. No Flutter
/// imports → unit-testable.
class QrSecurity {
  const QrSecurity._();

  static const _shorteners = {
    'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'ow.ly', 'is.gd', 'buff.ly',
    'rebrand.ly', 'cutt.ly', 'shorturl.at', 't.ly', 'rb.gy',
  };

  static const _suspiciousTlds = {
    '.zip', '.mov', '.xyz', '.top', '.tk', '.gq', '.ml', '.cf', '.ga',
    '.work', '.click', '.link', '.country', '.kim', '.loan',
  };

  /// Assess [parsed]. Non-URL payloads are generally safe but personal-data
  /// payloads (contact, Wi-Fi password) raise a privacy caution.
  static SecurityVerdict assess(ParsedQr parsed) {
    if (parsed.type == QrType.url || parsed.type == QrType.appLink) {
      return _assessUrl(parsed);
    }
    if (parsed.type == QrType.upi || parsed.type == QrType.crypto) {
      return const SecurityVerdict(
        level: RiskLevel.caution,
        score: 40,
        confidence: 0.6,
        reasons: [
          'Payment payload — verify the recipient before paying.',
        ],
      );
    }
    if (parsed.type == QrType.wifi &&
        (parsed.fields['password']?.isNotEmpty ?? false)) {
      return const SecurityVerdict(
        level: RiskLevel.safe,
        score: 5,
        confidence: 0.9,
        reasons: ['Contains a Wi-Fi password — keep this code private.'],
      );
    }
    return const SecurityVerdict(
      level: RiskLevel.safe,
      score: 0,
      confidence: 0.95,
      reasons: [],
    );
  }

  static SecurityVerdict _assessUrl(ParsedQr parsed) {
    final url = parsed.fields['url'] ?? parsed.raw;
    final uri = Uri.tryParse(url);
    final reasons = <String>[];
    var score = 0;

    if (uri == null) {
      return const SecurityVerdict(
        level: RiskLevel.caution,
        score: 45,
        confidence: 0.5,
        reasons: ['Malformed link — could not be parsed.'],
      );
    }

    final host = uri.host.toLowerCase();
    final scheme = uri.scheme.toLowerCase();

    // Non-HTTPS.
    if (scheme == 'http') {
      score += 20;
      reasons.add('Not secure (uses http, not https).');
    }

    // Embedded credentials: user:pass@host.
    if (uri.userInfo.isNotEmpty) {
      score += 40;
      reasons.add('Link embeds login credentials — a common phishing trick.');
    }

    // Raw IP address as host.
    if (_isIpHost(host)) {
      score += 35;
      reasons.add('Uses a raw IP address instead of a domain name.');
    }

    // URL shortener → real destination hidden.
    if (_shorteners.contains(host)) {
      score += 25;
      reasons.add('Shortened link — the real destination is hidden.');
    }

    // Punycode / IDN homograph.
    if (host.contains('xn--')) {
      score += 30;
      reasons.add('Internationalised domain — may impersonate a real site.');
    }

    // Excessive subdomains (e.g. paypal.com.secure-login.example.ru).
    final labels = host.split('.');
    if (labels.length >= 5) {
      score += 20;
      reasons.add('Unusually deep subdomain — possible lookalike domain.');
    }

    // Suspicious TLD.
    if (_suspiciousTlds.any(host.endsWith)) {
      score += 15;
      reasons.add('Uncommon domain ending often used for abuse.');
    }

    // "@" anywhere in the raw string after scheme (redirect-style trick).
    final afterScheme = url.contains('://')
        ? url.substring(url.indexOf('://') + 3)
        : url;
    if (afterScheme.contains('@') && uri.userInfo.isEmpty) {
      score += 20;
      reasons.add('Contains "@" in the address — may redirect elsewhere.');
    }

    score = score.clamp(0, 100);
    final level = score >= 40
        ? RiskLevel.danger
        : score >= 20
            ? RiskLevel.caution
            : RiskLevel.safe;

    // Offline heuristics can't confirm a site is *safe*, only flag risk — cap
    // confidence for clean URLs so we never over-promise without a lookup.
    final confidence = level == RiskLevel.safe ? 0.7 : 0.85;

    if (reasons.isEmpty) {
      reasons.add('No obvious risks found (offline check only).');
    }

    return SecurityVerdict(
      level: level,
      score: score,
      confidence: confidence,
      reasons: reasons,
    );
  }

  static bool _isIpHost(String host) =>
      RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) ||
      (host.contains(':') && RegExp(r'^[0-9a-f:]+$').hasMatch(host));
}
