import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/main.dart';
import 'package:meditrack/pages/home_page.dart';

void main() {
  testWidgets('App starts with SplashPage', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that SplashPage elements are present.
    expect(find.text('MediTrack'), findsOneWidget);
    expect(find.text('Your Health. Your Control.'), findsOneWidget);
    expect(find.text('Version 1.0'), findsOneWidget);

    // Pump timer to let splash complete and navigate to Onboarding page to avoid pending timer error.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('HomePage dashboard renders properly', (WidgetTester tester) async {
    // Build HomePage inside a MaterialApp.
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(),
      ),
    );
    await tester.pump();

    // Verify key dashboard elements are rendered.
    expect(find.text('Hey!! Jane'), findsOneWidget);
    expect(find.text('You have 3 doses today'), findsOneWidget);
    expect(find.text("Today's Doses"), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);

    // Verify schedule items.
    expect(find.text('Metformin 500mg'), findsOneWidget);
    expect(find.text('Lisinopril 10mg'), findsOneWidget);
    expect(find.text('Atorvastatin 20mg'), findsOneWidget);

    // Verify low stock alert.
    expect(find.text('Low Stock Alert'), findsOneWidget);
    expect(find.text('Metformin 500mg — only 5 pills left'), findsOneWidget);

    // Verify 7-Day Adherence card header.
    expect(find.text('7-Day Adherence'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
  });
}
