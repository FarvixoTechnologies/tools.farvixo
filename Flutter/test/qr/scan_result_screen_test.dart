import 'package:farvixo_all/features/tools/scanner/scan_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, String raw) async {
    // Tall surface so the whole result list (incl. bottom action buttons) is
    // built — otherwise off-screen ListView children aren't in the tree.
    await tester.binding.setSurfaceSize(const Size(1000, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ScanResultScreen(raw: raw),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders a URL result with its host + security card',
      (tester) async {
    await pump(tester, 'https://farvixo.com/tools');
    expect(find.text('Scan Result'), findsOneWidget);
    expect(find.text('farvixo.com'), findsWidgets);
    expect(find.text('Link'), findsWidgets);
    // Clean URL → "Looks safe" verdict + primary "Open Link" action.
    expect(find.text('Looks safe'), findsOneWidget);
    expect(find.text('Open Link'), findsOneWidget);
  });

  testWidgets('flags a high-risk link as danger', (tester) async {
    await pump(tester, 'https://user:pass@evil.example');
    expect(find.text('High risk'), findsOneWidget);
  });

  testWidgets('Wi-Fi payload offers Copy Password', (tester) async {
    await pump(tester, 'WIFI:S:Home;T:WPA;P:secret123;;');
    expect(find.text('Copy Password'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('always shows Copy + Share secondary actions', (tester) async {
    await pump(tester, 'just plain text');
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });
}
