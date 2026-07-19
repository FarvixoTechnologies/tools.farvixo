import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farvixo_all/app/app.dart';
import 'package:farvixo_all/providers/app_providers.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const FarvixoApp(),
      ),
    );

    await tester.pump();
    // Flush LaunchManager minDuration timer before dispose.
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('FARVIXO'), findsWidgets);
  });
}
