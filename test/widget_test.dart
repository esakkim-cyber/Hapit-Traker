import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_forge/app/app.dart';

void main() {
  testWidgets('HabitForgeApp launches with Onboarding on fresh install', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: HabitForgeApp(
          initialOnboardingCompleted: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify HabitForge branding and Onboarding welcome screen
    expect(find.text('HabitForge'), findsOneWidget);
    expect(find.text('Build better habits.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
