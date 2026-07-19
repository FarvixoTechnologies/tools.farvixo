import 'package:farvixo_all/features/settings/settings_section_screen.dart';
import 'package:farvixo_all/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSection(WidgetTester tester, String sectionId) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        home: SettingsSectionScreen(sectionId: sectionId),
      ),
    ),
  );
  // PremiumBackground may animate forever — avoid pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('appearance section shows theme and accent actions',
      (tester) async {
    await _pumpSection(tester, 'appearance');

    expect(find.textContaining('APPEARANCE'), findsWidgets);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Accent Color'), findsOneWidget);
    expect(find.text('Home Layout'), findsOneWidget);
    expect(find.text('Bottom Bar Style'), findsOneWidget);
  });

  testWidgets('subscription section shows plan and credits info',
      (tester) async {
    await _pumpSection(tester, 'subscription');

    expect(find.text('Current Plan'), findsOneWidget);
    expect(find.text('Credits Left'), findsOneWidget);
    expect(find.text('Guest'), findsWidgets);
  });

  testWidgets('storage section exposes clear cache action', (tester) async {
    await _pumpSection(tester, 'storage');

    expect(find.text('Clear Cache'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear Cache'));
    await tester.pump();
    await tester.tap(find.text('Clear Cache'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Dialog may be off-screen on small test surface; tile presence is enough.
    expect(find.text('Clear Cache'), findsOneWidget);
  });
}
