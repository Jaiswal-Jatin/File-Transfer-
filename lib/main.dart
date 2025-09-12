import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/device.dart';
import 'providers/app_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/home_screen.dart';
import 'services/file_service.dart';
import 'services/network_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/settings_service.dart';
import 'utils/theme.dart';

// Global navigator key to allow navigation from outside the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// This function will be called when a notification is tapped.
void onNotificationTap(Device device) {
  // Use the global navigator key to push the ChatScreen.
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ChatScreen(device: device),
    ),
  );
}

void main() async {
  // Ensure that plugin services are initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the notification service
  final notificationService = NotificationService(onNotificationTap: onNotificationTap);
  await notificationService.initialize();

  runApp(MyApp(notificationService: notificationService));
}

class MyApp extends StatelessWidget {
  final NotificationService notificationService;

  const MyApp({super.key, required this.notificationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Services
        Provider<SettingsService>(create: (_) => SettingsService()),
        Provider<PermissionService>(create: (_) => PermissionService()),
        Provider<FileService>(create: (_) => FileService()),
        Provider<NetworkService>(
          create: (_) => NetworkService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<NotificationService>.value(value: notificationService),

        // App State Providers
        ChangeNotifierProvider<AppProvider>(
          create: (context) => AppProvider(context.read<SettingsService>()),
        ),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ChangeNotifierProvider<TransferProvider>(create: (_) => TransferProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'P2P File Share',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appProvider.themeMode,
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}