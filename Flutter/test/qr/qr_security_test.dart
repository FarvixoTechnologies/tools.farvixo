import 'package:farvixo_all/features/tools/scanner/services/qr_parser.dart';
import 'package:farvixo_all/features/tools/scanner/services/qr_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SecurityVerdict verdictFor(String raw) =>
      QrSecurity.assess(QrParser.parse(raw));

  group('QrSecurity', () {
    test('clean https URL is safe', () {
      final v = verdictFor('https://farvixo.com');
      expect(v.level, RiskLevel.safe);
      expect(v.score, lessThan(20));
    });

    test('http (non-secure) raises caution', () {
      final v = verdictFor('http://example.com');
      expect(v.reasons.any((r) => r.contains('http')), isTrue);
      expect(v.score, greaterThanOrEqualTo(20));
    });

    test('embedded credentials flagged as danger', () {
      final v = verdictFor('https://user:pass@evil.example');
      expect(v.level, RiskLevel.danger);
    });

    test('raw IP host flagged', () {
      final v = verdictFor('http://192.168.1.1/login');
      expect(v.score, greaterThanOrEqualTo(45));
      expect(v.level, RiskLevel.danger);
    });

    test('URL shortener flagged as caution', () {
      final v = verdictFor('https://bit.ly/xyz');
      expect(v.level, RiskLevel.caution);
      expect(v.reasons.any((r) => r.toLowerCase().contains('hidden')), isTrue);
    });

    test('punycode homograph flagged', () {
      final v = verdictFor('https://xn--pple-43d.com');
      expect(v.score, greaterThanOrEqualTo(20));
    });

    test('deep subdomain lookalike flagged', () {
      final v = verdictFor('https://paypal.com.secure.login.evil.ru');
      expect(v.reasons, isNotEmpty);
      expect(v.level, isNot(RiskLevel.safe));
    });

    test('payment payload is caution', () {
      final v = verdictFor('upi://pay?pa=x@bank&am=10');
      expect(v.level, RiskLevel.caution);
    });

    test('plain text is safe with high confidence', () {
      final v = verdictFor('hello world');
      expect(v.level, RiskLevel.safe);
      expect(v.confidence, greaterThan(0.8));
    });

    test('never throws on hostile input', () {
      for (final bad in ['http://', 'https://@@@', 'ftp://x', '://nohost']) {
        expect(() => verdictFor(bad), returnsNormally, reason: bad);
      }
    });
  });
}
