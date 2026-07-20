import 'package:farvixo_all/features/tools/scanner/models/qr_type.dart';
import 'package:farvixo_all/features/tools/scanner/services/qr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QrParser', () {
    test('parses https URL', () {
      final r = QrParser.parse('https://farvixo.com/tools?ref=qr');
      expect(r.type, QrType.url);
      expect(r.title, 'farvixo.com');
      expect(r.fields['scheme'], 'https');
    });

    test('promotes bare domain to https URL', () {
      final r = QrParser.parse('example.com/path');
      expect(r.type, QrType.url);
      expect(r.fields['url'], 'https://example.com/path');
      expect(r.raw, 'example.com/path');
    });

    test('parses Wi-Fi with escaped separators', () {
      final r = QrParser.parse(r'WIFI:S:My\;Net;T:WPA;P:p\:ass;H:false;;');
      expect(r.type, QrType.wifi);
      expect(r.fields['ssid'], 'My;Net');
      expect(r.fields['password'], 'p:ass');
      expect(r.fields['security'], 'WPA');
    });

    test('parses vCard name/phone/email', () {
      const v = 'BEGIN:VCARD\nVERSION:3.0\nFN:Ada Lovelace\n'
          'ORG:Analytical Engines\nTEL:+15551234567\n'
          'EMAIL:ada@example.com\nEND:VCARD';
      final r = QrParser.parse(v);
      expect(r.type, QrType.contact);
      expect(r.title, 'Ada Lovelace');
      expect(r.fields['phone'], '+15551234567');
      expect(r.fields['email'], 'ada@example.com');
    });

    test('parses MECARD', () {
      final r = QrParser.parse('MECARD:N:Doe,John;TEL:5551234;EMAIL:j@d.com;;');
      expect(r.type, QrType.contact);
      expect(r.fields['phone'], '5551234');
    });

    test('parses mailto with subject', () {
      final r = QrParser.parse('mailto:hi@farvixo.com?subject=Hello');
      expect(r.type, QrType.email);
      expect(r.fields['address'], 'hi@farvixo.com');
      expect(r.fields['subject'], 'Hello');
    });

    test('parses SMSTO', () {
      final r = QrParser.parse('SMSTO:+15550001111:Call me');
      expect(r.type, QrType.sms);
      expect(r.fields['number'], '+15550001111');
      expect(r.fields['message'], 'Call me');
    });

    test('parses tel', () {
      final r = QrParser.parse('tel:+441632960961');
      expect(r.type, QrType.phone);
      expect(r.fields['number'], '+441632960961');
    });

    test('parses geo', () {
      final r = QrParser.parse('geo:37.7749,-122.4194');
      expect(r.type, QrType.geo);
      expect(r.fields['lat'], '37.7749');
      expect(r.fields['lng'], '-122.4194');
    });

    test('parses UPI', () {
      final r = QrParser.parse('upi://pay?pa=merchant@bank&pn=Store&am=99.50');
      expect(r.type, QrType.upi);
      expect(r.fields['vpa'], 'merchant@bank');
      expect(r.fields['amount'], '99.50');
      expect(r.subtitle, '₹99.50');
    });

    test('parses bitcoin', () {
      final r = QrParser.parse('bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa');
      expect(r.type, QrType.crypto);
      expect(r.fields['coin'], 'bitcoin');
    });

    test('recognises app links', () {
      expect(QrParser.parse('https://wa.me/15551234').type, QrType.appLink);
      expect(QrParser.parse('tg://resolve?domain=x').type, QrType.appLink);
    });

    test('falls back to text', () {
      final r = QrParser.parse('just some plain text');
      expect(r.type, QrType.text);
    });

    test('handles empty and malformed input without throwing', () {
      for (final bad in ['', '   ', 'WIFI:', 'BEGIN:VCARD', 'geo:', 'upi://',
        'mailto:', 'tel:', ';;;;', 'WIFI:::::;;']) {
        expect(() => QrParser.parse(bad), returnsNormally, reason: bad);
        expect(QrParser.parse(bad).raw, bad.trim().isEmpty ? bad : bad.trim());
      }
    });
  });
}
