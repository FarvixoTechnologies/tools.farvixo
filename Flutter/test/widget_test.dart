import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farvixo_all/app/app.dart';
import 'package:farvixo_all/providers/app_providers.dart';

void main() {
  testWidgets('App boots to splash and navigates to onboarding',
      (WidgetTester tester) async {
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

    // Splash is visible first (v2.0.0 shows the uppercase wordmark).
    expect(find.text('FARVIXO'), findsWidgets);

    // Fire the splash timer and settle navigation.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // First run → onboarding welcome (Get Started + Login).
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.textContaining('Login'), findsWidgets);
  });
}
