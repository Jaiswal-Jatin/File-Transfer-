// ignore_for_file: prefer_expression_function_bodies

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/discovery_service.dart';
import '../services/settings_service.dart';
import '../services/messaging_service.dart'; // Import MessagingService
import '../models/device.dart';
import '../widgets/device_card.dart';
import '../widgets/manual_connect_dialog.dart';
import 'unified_chat_screen.dart'; // Updated import to use unified chat screen instead of send file screen
import 'qr_code_screen.dart'; // Import QR code generation screen
import 'qr_scanner_screen.dart'; // Import QR code scanner screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final discoveryService = context.read<DiscoveryService>();
      final settingsService = context.read<SettingsService>();
      
      discoveryService.setSettingsService(settingsService);
      
      discoveryService.setConnectionDialogCallback(_showConnectionConfirmationDialog);
      
      if (settingsService.isDiscoverable) {
        discoveryService.startAdvertising();
      }
      discoveryService.startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'P2P File Share',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Consumer<DiscoveryService>(
            builder: (context, discoveryService, child) {
              return IconButton(
                icon: Icon(
                  discoveryService.isDiscovering 
                    ? Icons.refresh 
                    : Icons.refresh_outlined,
                ),
                onPressed: () async {
                  if (discoveryService.isDiscovering) {
                    await discoveryService.stopDiscovery();
                  } else {
                    await discoveryService.startDiscovery();
                  }
                },
                tooltip: discoveryService.isDiscovering 
                  ? 'Stop Discovery' 
                  : 'Start Discovery',
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'manual_connect':
                  _showManualConnectDialog();
                  break;
                case 'toggle_discoverable':
                  final settingsService = context.read<SettingsService>();
                  final discoveryService = context.read<DiscoveryService>();
                  
                  await settingsService.setDiscoverable(!settingsService.isDiscoverable);
                  
                  if (settingsService.isDiscoverable) {
                    await discoveryService.startAdvertising();
                  } else {
                    await discoveryService.stopAdvertising();
                  }
                  break;
                case 'show_qr_code':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const QRCodeScreen()),
                  );
                  break;
                case 'scan_qr_code':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const QRScannerScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manual_connect',
                child: Row(
                  children: [
                    Icon(Icons.add_link),
                    SizedBox(width: 12),
                    Text('Manual Connect'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_discoverable',
                child: Row(
                  children: [
                    Consumer<SettingsService>(
                      builder: (context, settings, child) {
                        return Icon(
                          settings.isDiscoverable 
                            ? Icons.visibility_off 
                            : Icons.visibility,
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Consumer<SettingsService>(
                      builder: (context, settings, child) {
                        return Text(
                          settings.isDiscoverable 
                            ? 'Hide from Others' 
                            : 'Make Discoverable',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'show_qr_code',
                child: Row(
                  children: [
                    Icon(Icons.qr_code),
                    SizedBox(width: 12),
                    Text('Show My QR Code'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scan_qr_code',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_scanner),
                    SizedBox(width: 12),
                    Text('Scan QR Code'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final discoveryService = context.read<DiscoveryService>();
          await discoveryService.refreshDevices();
        },
        child: Column(
          children: [
            // Status Card
            Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Consumer<SettingsService>(
                        builder: (context, settings, child) {
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.smartphone,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      settings.deviceName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Consumer<DiscoveryService>(
                                      builder: (context, discovery, child) {
                                        return Text(
                                          discovery.isAdvertising 
                                            ? 'Visible to nearby devices' 
                                            : 'Hidden from other devices',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: discovery.isAdvertising 
                                              ? Colors.green 
                                              : Colors.orange,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Consumer<DiscoveryService>(
              builder: (context, discoveryService, child) {
                final connectedDevices = discoveryService.connectedDevices;
                
                if (connectedDevices.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Connected Devices',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${connectedDevices.length}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...connectedDevices.map((device) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DeviceCard(
                          device: device,
                          onTap: () => _navigateToChat(device),
                          onDisconnect: () => _disconnectDevice(device),
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            Expanded(
              child: Consumer<DiscoveryService>(
                builder: (context, discoveryService, child) {
                  final devices = discoveryService.discoveredDevices;
                  
                  if (discoveryService.isDiscovering && devices.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Searching for nearby devices...'),
                        ],
                      ),
                    );
                  }
                  
                  if (devices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_other,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh or make sure other devices\nare on the same network with P2P File Share running',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => discoveryService.startDiscovery(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              'Nearby Devices',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${devices.length}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final device = devices[index];
                            return DeviceCard(
                              device: device,
                              onTap: () => _connectAndNavigateToChat(device),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualConnectDialog() {
    showDialog(
      context: context,
      builder: (context) => ManualConnectDialog(
        onConnect: (ipAddress, port) async {
          try {
            await context.read<DiscoveryService>().addManualDevice(ipAddress, port);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Found device at $ipAddress:$port'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to connect: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _connectAndNavigateToChat(Device device) async {
    try {
      final discoveryService = context.read<DiscoveryService>();
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Waiting for connection...'),
            ],
          ),
        ),
      );
      
      // Connect to device
      await discoveryService.connectToDevice(device);
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (discoveryService.connectedDevices.any((d) => d.id == device.id)) {
        _navigateToChat(device);
      } else {
        throw Exception('Connection was not established');
      }
      
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToChat(Device device) {
    try {
      if (!mounted) return;
      
      MessagingService? messagingService;
      try {
        messagingService = Provider.of<MessagingService>(context, listen: false);
      } catch (providerError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messaging service not available. Please restart the app.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (messagingService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messaging service not initialized. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UnifiedChatScreen(
            device: device,
            messagingService: messagingService!,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _disconnectDevice(Device device) async {
    try {
      if (!mounted) return;
      
      DiscoveryService? discoveryService;
      try {
        discoveryService = Provider.of<DiscoveryService>(context, listen: false);
      } catch (providerError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discovery service not available. Please restart the app.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      if (discoveryService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discovery service not initialized. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      await discoveryService.disconnectDevice(device);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from ${device.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showConnectionConfirmationDialog(Device device) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connection Request'),
          content: Text('${device.name} (${device.ipAddress}) wants to connect with you. Do you want to accept?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Decline'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              child: const Text('Accept'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }
}
