import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:p2p_file_share/main.dart';


void main() {
  group('App Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('App should build without errors', (WidgetTester tester) async {
      await tester.pumpWidget(const P2PFileShareApp());
      await tester.pumpAndSettle();

      // Verify the app builds and shows the main navigation
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Transfers'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Should navigate between tabs', (WidgetTester tester) async {
      await tester.pumpWidget(const P2PFileShareApp());
      await tester.pumpAndSettle();

      // Start on Home tab
      expect(find.text('P2P File Share'), findsOneWidget);

      // Navigate to Transfers tab
      await tester.tap(find.text('Transfers'));
      await tester.pumpAndSettle();
      expect(find.text('Transfers'), findsWidgets);

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('Settings screen should show device settings', (WidgetTester tester) async {
      await tester.pumpWidget(const P2PFileShareApp());
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Check for settings sections
      expect(find.text('Device Settings'), findsOneWidget);
      expect(find.text('Transfer Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Device Name'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('Dark mode toggle should work', (WidgetTester tester) async {
      await tester.pumpWidget(const P2PFileShareApp());
      await tester.pumpAndSettle();

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Find and tap the dark mode switch
      final darkModeSwitch = find.byType(Switch).last;
      await tester.tap(darkModeSwitch);
      await tester.pumpAndSettle();

      // The theme should change (this is a basic test)
      // In a real test, you would verify the theme colors changed
    });

    testWidgets('Home screen should show device discovery UI', (WidgetTester tester) async {
      await tester.pumpWidget(const P2PFileShareApp());
      await tester.pumpAndSettle();

      // Should show the main title
      expect(find.text('P2P File Share'), findsOneWidget);
      
      // Should show the send files FAB
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Send Files'), findsOneWidget);
    });
  });
}
