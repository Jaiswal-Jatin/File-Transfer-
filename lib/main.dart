// ignore_for_file: prefer_expression_function_bodies, cascade_invocations, directives_ordering

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/settings_service.dart';
import 'services/discovery_service.dart';
import 'services/transfer_service.dart';
import 'services/notification_service.dart';
import 'services/messaging_service.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await NotificationService.initialize();
  
  runApp(const P2PFileShareApp());
}

class P2PFileShareApp extends StatelessWidget {
  const P2PFileShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(
          create: (context) {
            final discoveryService = DiscoveryService();
            final settingsService = Provider.of<SettingsService>(context, listen: false);
            discoveryService.setSettingsService(settingsService);
            // Start advertising and discovery when the app starts
            settingsService.addListener(() {
              if (settingsService.isDiscoverable) {
                discoveryService.startAdvertising();
                discoveryService.startDiscovery();
              } else {
                discoveryService.stopAdvertising();
                discoveryService.stopDiscovery();
              }
            });
            if (settingsService.isDiscoverable) {
              discoveryService.startAdvertising();
              discoveryService.startDiscovery();
            }
            return discoveryService;
          },
        ),
        ChangeNotifierProvider(create: (_) => TransferService()),
        ChangeNotifierProvider(
          create: (_) {
            final messagingService = MessagingService();
            messagingService.startMessageServer();
            return messagingService;
          },
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'P2P File Share',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const MainScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
