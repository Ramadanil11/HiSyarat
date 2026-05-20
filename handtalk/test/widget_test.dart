import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handtalk/main.dart';
import 'package:handtalk/core/constants.dart';

void main() {
  group('HandTalk App Smoke Tests', () {
    testWidgets('App launches with splash screen', (WidgetTester tester) async {
      await tester.pumpWidget(const HandTalkApp());
      // Splash screen should show app name
      expect(find.text(AppConstants.appName), findsOneWidget);
    });

    testWidgets('Splash screen shows tagline', (WidgetTester tester) async {
      await tester.pumpWidget(const HandTalkApp());
      expect(find.text(AppConstants.appTagline), findsOneWidget);
    });

    testWidgets('Splash screen shows theme badge', (WidgetTester tester) async {
      await tester.pumpWidget(const HandTalkApp());
      expect(find.text(AppConstants.appTheme), findsOneWidget);
    });

    testWidgets('Splash screen shows loading indicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(const HandTalkApp());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
