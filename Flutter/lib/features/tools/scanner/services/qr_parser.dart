import '../models/parsed_qr.dart';
import '../models/qr_type.dart';

/// Pure-Dart parser: raw decoded QR/barcode string → typed [ParsedQr].
///
/// Deliberately defensive — every branch tolerates malformed input and falls
/// back to [QrType.text] rather than throwing, so a hostile or truncated code
/// can never crash the scanner. No Flutter/plugin imports (unit-testable).
class QrParser {
  const QrParser._();

  /// Parse [raw] into a typed payload. Trims surrounding whitespace but keeps
  /// the original string in [ParsedQr.raw].
  static ParsedQr parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return ParsedQr(type: QrType.text, raw: raw, title: 'Empty code');
    }
    final lower = value.toLowerCase();

    if (lower.startsWith('wifi:')) return _wifi(value);
    if (lower.startsWith('begin:vcard')) return _vcard(value);
    if (lower.startsWith('mecard:')) return _mecard(value);
    if (lower.startsWith('begin:vevent') || lower.contains('begin:vevent')) {
      return _vevent(value);
    }
    if (lower.startsWith('mailto:')) return _mailto(value);
    if (lower.startsWith('matmsg:')) return _matmsg(value);
    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) {
      return _sms(value);
    }
    if (lower.startsWith('tel:')) return _tel(value);
    if (lower.startsWith('geo:')) return _geo(value);
    if (lower.startsWith('upi://')) return _upi(value);
    if (_cryptoSchemes.any(lower.startsWith)) return _crypto(value);
    // App links (incl. https wa.me / t.me) are checked before the generic URL
    // branch so they resolve to [QrType.appLink], not a plain link.
    if (_appLinkSchemes.any(lower.startsWith)) {
      return ParsedQr(
        type: QrType.appLink,
        raw: value,
        title: 'Open in app',
        subtitle: value,
      );
    }
    if (_isHttpUrl(lower)) return _url(value);
    // A bare host like "example.com/path" with no scheme → treat as URL.
    if (_looksLikeBareDomain(value)) {
      return _url('https://$value', displayRaw: value);
    }

    return ParsedQr(type: QrType.text, raw: value, title: _preview(value));
  }

  // ---------------------------------------------------------------- URL

  static ParsedQr _url(String value, {String? displayRaw}) {
    final uri = Uri.tryParse(value);
    final host = uri?.host ?? value;
    final scheme = uri?.scheme ?? '';
    final path = (uri?.path ?? '').replaceAll(RegExp(r'/$'), '');
    final query = uri?.hasQuery ?? false;
    return ParsedQr(
      type: QrType.url,
      raw: displayRaw ?? value,
      title: host.isEmpty ? value : host,
      subtitle: path.isNotEmpty || query ? '$path${query ? '?…' : ''}' : null,
      fields: {
        'url': value,
        if (scheme.isNotEmpty) 'scheme': scheme,
        if (host.isNotEmpty) 'host': host,
      },
    );
  }

  // ---------------------------------------------------------------- Wi-Fi

  static ParsedQr _wifi(String value) {
    // WIFI:S:<ssid>;T:<WPA|WEP|nopass>;P:<pass>;H:<true|false>;;
    final body = value.substring('wifi:'.length);
    final map = _semicolonKv(body);
    final ssid = map['s'] ?? '';
    final auth = (map['t'] ?? 'nopass').toUpperCase();
    return ParsedQr(
      type: QrType.wifi,
      raw: value,
      title: ssid.isEmpty ? 'Wi-Fi network' : ssid,
      subtitle: auth == 'NOPASS' ? 'Open network' : '$auth secured',
      fields: {
        'ssid': ssid,
        'security': auth,
        if (map['p'] != null) 'password': map['p']!,
        'hidden': (map['h'] ?? 'false'),
      },
    );
  }

  // ---------------------------------------------------------------- vCard

  static ParsedQr _vcard(String value) {
    final lines = value.split(RegExp(r'\r?\n'));
    String name = '';
    String org = '';
    String phone = '';
    String email = '';
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.startsWith('FN:')) {
        name = line.substring(3).trim();
      } else if (name.isEmpty && upper.startsWith('N:')) {
        name = line
            .substring(2)
            .split(';')
            .where((s) => s.trim().isNotEmpty)
            .join(' ')
            .trim();
      } else if (upper.startsWith('ORG:')) {
        org = line.substring(4).trim();
      } else if (upper.startsWith('TEL') && phone.isEmpty) {
        phone = line.split(':').last.trim();
      } else if (upper.startsWith('EMAIL') && email.isEmpty) {
        email = line.split(':').last.trim();
      }
    }
    return ParsedQr(
      type: QrType.contact,
      raw: value,
      title: name.isEmpty ? 'Contact' : name,
      subtitle: org.isNotEmpty ? org : (phone.isNotEmpty ? phone : email),
      fields: {
        if (name.isNotEmpty) 'name': name,
        if (org.isNotEmpty) 'org': org,
        if (phone.isNotEmpty) 'phone': phone,
        if (email.isNotEmpty) 'email': email,
      },
    );
  }

  static ParsedQr _mecard(String value) {
    // MECARD:N:<name>;TEL:<tel>;EMAIL:<email>;;
    final body = value.substring('mecard:'.length);
    final map = _semicolonKv(body, lowercaseKeys: false);
    final name = map['N'] ?? map['n'] ?? '';
    final phone = map['TEL'] ?? map['tel'] ?? '';
    final email = map['EMAIL'] ?? map['email'] ?? '';
    return ParsedQr(
      type: QrType.contact,
      raw: value,
      title: name.isEmpty ? 'Contact' : name.replaceAll(',', ' ').trim(),
      subtitle: phone.isNotEmpty ? phone : email,
      fields: {
        if (name.isNotEmpty) 'name': name.replaceAll(',', ' ').trim(),
        if (phone.isNotEmpty) 'phone': phone,
        if (email.isNotEmpty) 'email': email,
      },
    );
  }

  // ---------------------------------------------------------------- Event

  static ParsedQr _vevent(String value) {
    final lines = value.split(RegExp(r'\r?\n'));
    String summary = '';
    String start = '';
    String location = '';
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.startsWith('SUMMARY:')) {
        summary = line.substring(8).trim();
      } else if (upper.startsWith('DTSTART')) {
        start = line.split(':').last.trim();
      } else if (upper.startsWith('LOCATION:')) {
        location = line.substring(9).trim();
      }
    }
    return ParsedQr(
      type: QrType.event,
      raw: value,
      title: summary.isEmpty ? 'Calendar event' : summary,
      subtitle: location.isNotEmpty ? location : (start.isNotEmpty ? start : null),
      fields: {
        if (summary.isNotEmpty) 'summary': summary,
        if (start.isNotEmpty) 'start': start,
        if (location.isNotEmpty) 'location': location,
      },
    );
  }

  // ---------------------------------------------------------------- Email

  static ParsedQr _mailto(String value) {
    final uri = Uri.tryParse(value);
    final address = uri?.path ?? value.substring('mailto:'.length);
    final subject = uri?.queryParameters['subject'] ?? '';
    final body = uri?.queryParameters['body'] ?? '';
    return ParsedQr(
      type: QrType.email,
      raw: value,
      title: address.isEmpty ? 'Email' : address,
      subtitle: subject.isEmpty ? null : subject,
      fields: {
        'address': address,
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );
  }

  static ParsedQr _matmsg(String value) {
    // MATMSG:TO:<addr>;SUB:<subject>;BODY:<body>;;
    final body = value.substring('matmsg:'.length);
    final map = _semicolonKv(body, lowercaseKeys: false);
    final to = map['TO'] ?? '';
    final sub = map['SUB'] ?? '';
    return ParsedQr(
      type: QrType.email,
      raw: value,
      title: to.isEmpty ? 'Email' : to,
      subtitle: sub.isNotEmpty ? sub : null,
      fields: {
        if (to.isNotEmpty) 'address': to,
        if (sub.isNotEmpty) 'subject': sub,
        if ((map['BODY'] ?? '').isNotEmpty) 'body': map['BODY']!,
      },
    );
  }

  // ---------------------------------------------------------------- SMS / Tel

  static ParsedQr _sms(String value) {
    final rest = value.contains(':')
        ? value.substring(value.indexOf(':') + 1)
        : '';
    final parts = rest.split(':');
    final number = parts.isNotEmpty ? parts.first.trim() : '';
    final message = parts.length > 1 ? parts.sublist(1).join(':').trim() : '';
    return ParsedQr(
      type: QrType.sms,
      raw: value,
      title: number.isEmpty ? 'SMS' : number,
      subtitle: message.isNotEmpty ? message : null,
      fields: {
        if (number.isNotEmpty) 'number': number,
        if (message.isNotEmpty) 'message': message,
      },
    );
  }

  static ParsedQr _tel(String value) {
    final number = value.substring('tel:'.length).trim();
    return ParsedQr(
      type: QrType.phone,
      raw: value,
      title: number.isEmpty ? 'Phone' : number,
      fields: {if (number.isNotEmpty) 'number': number},
    );
  }

  // ---------------------------------------------------------------- Geo

  static ParsedQr _geo(String value) {
    final body = value.substring('geo:'.length).split('?').first;
    final coords = body.split(',');
    final lat = coords.isNotEmpty ? coords[0].trim() : '';
    final lng = coords.length > 1 ? coords[1].trim() : '';
    return ParsedQr(
      type: QrType.geo,
      raw: value,
      title: lat.isEmpty ? 'Location' : '$lat, $lng',
      subtitle: 'Map coordinates',
      fields: {
        if (lat.isNotEmpty) 'lat': lat,
        if (lng.isNotEmpty) 'lng': lng,
      },
    );
  }

  // ---------------------------------------------------------------- UPI

  static ParsedQr _upi(String value) {
    final uri = Uri.tryParse(value);
    final q = uri?.queryParameters ?? const {};
    final payee = q['pn'] ?? q['pa'] ?? 'Payment';
    final amount = q['am'] ?? '';
    return ParsedQr(
      type: QrType.upi,
      raw: value,
      title: payee,
      subtitle: amount.isNotEmpty ? '₹$amount' : (q['pa'] ?? 'UPI payment'),
      fields: {
        if (q['pa'] != null) 'vpa': q['pa']!,
        if (q['pn'] != null) 'payee': q['pn']!,
        if (amount.isNotEmpty) 'amount': amount,
        if (q['tn'] != null) 'note': q['tn']!,
      },
    );
  }

  // ---------------------------------------------------------------- Crypto

  static ParsedQr _crypto(String value) {
    final scheme = value.split(':').first.toLowerCase();
    final rest = value.substring(value.indexOf(':') + 1).split('?').first;
    final uri = Uri.tryParse(value);
    final amount = uri?.queryParameters['amount'] ?? '';
    return ParsedQr(
      type: QrType.crypto,
      raw: value,
      title: '${_cryptoLabel(scheme)} address',
      subtitle: amount.isNotEmpty ? '$amount $scheme' : _shorten(rest),
      fields: {
        'coin': scheme,
        'address': rest,
        if (amount.isNotEmpty) 'amount': amount,
      },
    );
  }

  // ---------------------------------------------------------------- helpers

  static const _cryptoSchemes = ['bitcoin:', 'ethereum:', 'litecoin:'];
  static const _appLinkSchemes = [
    'whatsapp:',
    'tg:',
    'telegram:',
    'https://wa.me/',
    'https://t.me/',
    'instagram:',
    'fb:',
    'spotify:',
  ];

  static bool _isHttpUrl(String lower) =>
      lower.startsWith('http://') || lower.startsWith('https://');

  static bool _looksLikeBareDomain(String value) {
    if (value.contains(' ') || value.contains('\n')) return false;
    final host = value.split('/').first;
    return RegExp(
      r'^([a-z0-9-]+\.)+[a-z]{2,}$',
      caseSensitive: false,
    ).hasMatch(host);
  }

  static String _cryptoLabel(String scheme) => switch (scheme) {
        'bitcoin' => 'Bitcoin',
        'ethereum' => 'Ethereum',
        'litecoin' => 'Litecoin',
        _ => scheme,
      };

  /// Parse a `k:v;k:v;` body into a map. Handles backslash-escaped `\;` and
  /// `\:` per the WIFI/MECARD conventions.
  static Map<String, String> _semicolonKv(
    String body, {
    bool lowercaseKeys = true,
  }) {
    final out = <String, String>{};
    final buf = StringBuffer();
    final parts = <String>[];
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (c == r'\' && i + 1 < body.length) {
        buf.write(body[i + 1]);
        i++;
      } else if (c == ';') {
        parts.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    for (final p in parts) {
      final idx = p.indexOf(':');
      if (idx <= 0) continue;
      final key = p.substring(0, idx);
      out[lowercaseKeys ? key.toLowerCase() : key] = p.substring(idx + 1);
    }
    return out;
  }

  static String _preview(String value) =>
      value.length <= 60 ? value : '${value.substring(0, 57)}…';

  static String _shorten(String value) => value.length <= 22
      ? value
      : '${value.substring(0, 10)}…${value.substring(value.length - 8)}';
}
