// ignore_for_file: prefer_expression_function_bodies

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/chat_provider.dart';
import '../services/network_service.dart';
import '../services/permission_service.dart';
import '../models/device.dart';
import 'device_discovery_screen.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import '../widgets/feature_card.dart';
import '../widgets/device_card.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final appProvider = context.read<AppProvider>();
    final permissionService = context.read<PermissionService>();
    final networkService = context.read<NetworkService>();
    
    await appProvider.initialize();
    await permissionService.requestAllPermissions();

    // Start the server to listen for incoming connections
    await networkService.initialize(appProvider.deviceName);
    await networkService.startDiscovery();

    _listenForConnectionRequests();
  }

  void _listenForConnectionRequests() {
    final networkService = context.read<NetworkService>();
    _eventSubscription = networkService.eventStream.listen((event) {
      if (mounted && event['type'] == NetworkService.msgTypeConnectionRequest) {
        final deviceInfo = event['deviceInfo'] as Map<String, dynamic>;
        final requestingDevice = Device.fromJson(deviceInfo);
        _showConnectionRequestDialog(requestingDevice);
      }
    });
  }

  Future<void> _showConnectionRequestDialog(Device device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connection Request'),
        content: Text('${device.name} wants to connect with you.'),
        actions: [
          TextButton(onPressed: () {
            context.read<NetworkService>().respondToConnection(device, false);
            Navigator.of(dialogContext).pop();
          }, child: const Text('Decline')),
          TextButton(onPressed: () {
            context.read<NetworkService>().respondToConnection(device, true);
            // Show connected notification
            context
                .read<NotificationService>()
                .showDeviceConnectedNotification(device);
            Navigator.of(dialogContext).pop();
            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(device: device)));
          }, child: const Text('Accept')),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    // This will clear the device list and send a new discovery broadcast.
    await context.read<NetworkService>().refreshDiscovery();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('P2P File Share'), actions: [
        IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()))),
        IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()))),
      ]),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: Consumer<AppProvider>(builder: (context, appProvider, child) {
          if (!appProvider.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }
          // Use a ListView to ensure the RefreshIndicator works even when content is short.
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Welcome, ${appProvider.deviceName}!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Share files instantly with nearby devices',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 32),
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.95,
                child: FeatureCard(
                    icon: Icons.cast_connected,
                    title: 'Connect to Device',
                    subtitle: 'Find and connect to share files & messages',
                    color: Theme.of(context).primaryColor,
                    onTap: _navigateToDiscovery),
              ),
            ),
            const SizedBox(height: 24),
            Text('Connected Devices',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StreamBuilder<List<Device>>(
                stream: context.watch<NetworkService>().deviceListStream,
                initialData: context.read<NetworkService>().discoveredDevices,
                builder: (context, snapshot) {
                  final chatProvider = context.watch<ChatProvider>();
                  final allDiscoveredDevices = snapshot.data ?? [];
                  final connectedDeviceIds = chatProvider.conversations.keys;
                  final connectedDevices = allDiscoveredDevices
                      .where((d) => connectedDeviceIds.contains(d.id))
                      .toList();
                  if (connectedDevices.isEmpty) {
                    return const Center(
                        heightFactor: 3,
                        child: Text('No devices with active chats.'));
                  }
                  // We can't use an Expanded ListView inside another ListView.
                  // So we use a Column of the widgets directly.
                  return Column(
                    children: connectedDevices
                        .map((device) => DeviceCard(
                            device: device.copyWith(isConnected: true),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ChatScreen(device: device)))))
                        .toList(),
                  );
                }),
          ]);
        }),
      ));
  void _navigateToDiscovery() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const DeviceDiscoveryScreen()));
  }
}
