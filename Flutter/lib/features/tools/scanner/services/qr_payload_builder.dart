/// Builds encoded QR payload strings from typed input — the inverse of
/// [QrParser]. Pure (no Flutter imports) so it's unit-testable, and round-trips
/// with the parser for the shared formats.
class QrPayloadBuilder {
  const QrPayloadBuilder._();

  /// Normalise a URL, defaulting to https:// when no scheme is present.
  static String url(String input) {
    final v = input.trim();
    if (v.isEmpty) return '';
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(v)) return v;
    return 'https://$v';
  }

  static String text(String input) => input;

  /// `WIFI:S:<ssid>;T:<WPA|WEP|nopass>;P:<pass>;H:<true|false>;;`
  static String wifi({
    required String ssid,
    String password = '',
    String auth = 'WPA',
    bool hidden = false,
  }) {
    final t = password.isEmpty ? 'nopass' : auth;
    final buf = StringBuffer('WIFI:S:${_esc(ssid)};T:$t;');
    if (password.isNotEmpty) buf.write('P:${_esc(password)};');
    if (hidden) buf.write('H:true;');
    buf.write(';');
    return buf.toString();
  }

  static String email({String address = '', String subject = '', String body = ''}) {
    final params = <String, String>{
      if (subject.isNotEmpty) 'subject': subject,
      if (body.isNotEmpty) 'body': body,
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return 'mailto:${address.trim()}$query';
  }

  static String phone(String number) => 'tel:${number.trim()}';

  static String sms({required String number, String message = ''}) =>
      message.isEmpty ? 'SMSTO:${number.trim()}' : 'SMSTO:${number.trim()}:$message';

  static String geo(String lat, String lng) => 'geo:${lat.trim()},${lng.trim()}';

  /// Minimal vCard 3.0.
  static String vcard({
    String name = '',
    String phone = '',
    String email = '',
    String org = '',
  }) {
    final buf = StringBuffer('BEGIN:VCARD\nVERSION:3.0\n');
    if (name.isNotEmpty) buf.write('FN:$name\n');
    if (org.isNotEmpty) buf.write('ORG:$org\n');
    if (phone.isNotEmpty) buf.write('TEL:$phone\n');
    if (email.isNotEmpty) buf.write('EMAIL:$email\n');
    buf.write('END:VCARD');
    return buf.toString();
  }

  /// `upi://pay?pa=<vpa>&pn=<name>&am=<amount>&tn=<note>`
  static String upi({
    required String vpa,
    String name = '',
    String amount = '',
    String note = '',
  }) {
    final params = <String, String>{
      'pa': vpa.trim(),
      if (name.isNotEmpty) 'pn': name,
      if (amount.isNotEmpty) 'am': amount,
      if (note.isNotEmpty) 'tn': note,
    };
    final query =
        params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return 'upi://pay?$query';
  }

  /// Escape the WIFI/MECARD special characters: `\ ; , : "`.
  static String _esc(String s) => s.replaceAllMapped(
        RegExp(r'([\\;,:"])'),
        (m) => '\\${m[1]}',
      );
}
