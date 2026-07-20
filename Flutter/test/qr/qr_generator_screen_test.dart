import 'package:farvixo_all/features/tools/scanner/qr_generator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const QrGeneratorScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows placeholder until content is entered', (tester) async {
    await pump(tester);
    expect(find.text('QR Generator'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('renders a live QR once a URL is typed', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'farvixo.com');
    await tester.pump();
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('switching type updates the subtitle + form', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Wi-Fi'));
    await tester.pump();
    expect(find.text('Network name (SSID)'), findsOneWidget);
  });
}
