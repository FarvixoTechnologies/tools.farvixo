import 'package:farvixo_all/features/tools/scanner/models/qr_type.dart';
import 'package:farvixo_all/features/tools/scanner/services/qr_parser.dart';
import 'package:farvixo_all/features/tools/scanner/services/qr_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QrPayloadBuilder', () {
    test('url adds https scheme when missing', () {
      expect(QrPayloadBuilder.url('farvixo.com'), 'https://farvixo.com');
      expect(QrPayloadBuilder.url('http://x.com'), 'http://x.com');
      expect(QrPayloadBuilder.url(''), '');
    });

    test('wifi escapes special characters', () {
      final s = QrPayloadBuilder.wifi(ssid: 'My;Net', password: 'p:ass');
      expect(s, contains(r'S:My\;Net'));
      expect(s, contains(r'P:p\:ass'));
    });

    test('wifi with no password uses nopass', () {
      expect(QrPayloadBuilder.wifi(ssid: 'Open'), contains('T:nopass'));
    });
  });

  group('round-trips through QrParser', () {
    test('url', () {
      final p = QrParser.parse(QrPayloadBuilder.url('farvixo.com/tools'));
      expect(p.type, QrType.url);
      expect(p.fields['host'], 'farvixo.com');
    });

    test('wifi', () {
      final p = QrParser.parse(
          QrPayloadBuilder.wifi(ssid: 'Home;1', password: 'pa:ss', auth: 'WPA'));
      expect(p.type, QrType.wifi);
      expect(p.fields['ssid'], 'Home;1');
      expect(p.fields['password'], 'pa:ss');
    });

    test('email', () {
      final p = QrParser.parse(QrPayloadBuilder.email(
          address: 'hi@farvixo.com', subject: 'Hello world'));
      expect(p.type, QrType.email);
      expect(p.fields['address'], 'hi@farvixo.com');
      expect(p.fields['subject'], 'Hello world');
    });

    test('phone', () {
      final p = QrParser.parse(QrPayloadBuilder.phone('+15551234'));
      expect(p.type, QrType.phone);
      expect(p.fields['number'], '+15551234');
    });

    test('sms', () {
      final p = QrParser.parse(
          QrPayloadBuilder.sms(number: '+15550000', message: 'hi'));
      expect(p.type, QrType.sms);
      expect(p.fields['number'], '+15550000');
      expect(p.fields['message'], 'hi');
    });

    test('geo', () {
      final p = QrParser.parse(QrPayloadBuilder.geo('37.77', '-122.41'));
      expect(p.type, QrType.geo);
      expect(p.fields['lat'], '37.77');
    });

    test('vcard', () {
      final p = QrParser.parse(QrPayloadBuilder.vcard(
          name: 'Ada Lovelace', phone: '123', email: 'a@b.com'));
      expect(p.type, QrType.contact);
      expect(p.title, 'Ada Lovelace');
      expect(p.fields['phone'], '123');
    });

    test('upi', () {
      final p = QrParser.parse(QrPayloadBuilder.upi(
          vpa: 'merchant@bank', name: 'Store', amount: '10'));
      expect(p.type, QrType.upi);
      expect(p.fields['vpa'], 'merchant@bank');
      expect(p.fields['amount'], '10');
    });
  });
}
