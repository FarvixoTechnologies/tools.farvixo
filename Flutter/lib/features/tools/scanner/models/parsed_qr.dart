import 'qr_type.dart';

/// A raw scan string parsed into a typed, display-ready payload.
///
/// Pure data — no Flutter imports — so it stays unit-testable. [fields] holds
/// the type-specific structured values (e.g. Wi-Fi `ssid`/`password`, contact
/// `name`/`phone`), keyed by stable lowercase names the result UI reads.
class ParsedQr {
  const ParsedQr({
    required this.type,
    required this.raw,
    required this.title,
    this.subtitle,
    this.fields = const {},
  });

  final QrType type;

  /// The original decoded string, always preserved verbatim.
  final String raw;

  /// Primary human-readable line (host for URLs, SSID for Wi-Fi, name for
  /// contacts, …). Never empty.
  final String title;

  /// Optional secondary line (page path, contact org, amount, …).
  final String? subtitle;

  /// Type-specific structured values.
  final Map<String, String> fields;

  /// The primary actionable URI for this payload, when one applies — used to
  /// drive the primary action button (open link, dial, mailto, geo, upi…).
  /// Null for payloads with no single canonical launch target (Wi-Fi, text).
  String? get actionUri => switch (type) {
        QrType.url || QrType.appLink => raw,
        QrType.phone => 'tel:${fields['number'] ?? ''}',
        QrType.sms => 'sms:${fields['number'] ?? ''}',
        QrType.email => 'mailto:${fields['address'] ?? ''}',
        QrType.geo => raw.startsWith('geo:') ? raw : null,
        QrType.upi => raw,
        _ => null,
      };
}
