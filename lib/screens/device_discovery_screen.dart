// ignore_for_file: prefer_expression_function_bodies

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/network_service.dart';
import '../models/device.dart';
import '../widgets/device_card.dart';
import 'chat_screen.dart'; // For navigation after connection

class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  late NetworkService _networkService;
  bool _isDiscovering = false;
  StreamSubscription? _eventSubscription;
  Device? _connectingDevice;

  @override
  void initState() {
    super.initState();
    _networkService = context.read<NetworkService>();
    // Discovery is already running from HomeScreen, we just refresh the list.
    _refreshDevices();
    _listenForConnectionResponses();
  }

  @override
  void dispose() {
    // Discovery is now started from home screen and should persist.
    // We only cancel the event listener for this screen.
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshDevices() async {
    setState(() => _isDiscovering = true);
    // The discovery service is already running. We can force a broadcast
    // or just rely on the periodic ones. For simplicity, we'll just update the UI state.
    // In a real app, you might want a specific refresh method in NetworkService.
    await Future.delayed(const Duration(seconds: 1)); // Simulate refresh
    setState(() {
      _isDiscovering = false;
    });
  }

  void _listenForConnectionResponses() {
    _eventSubscription = _networkService.eventStream.listen((event) {
      if (!mounted || event['type'] != NetworkService.msgTypeConnectionResponse) return;

      // We are waiting for a response from a specific device
      if (_connectingDevice != null && event['deviceInfo']['deviceId'] == _connectingDevice!.id) {
        Navigator.of(context).pop(); // Dismiss waiting dialog
        final respondingDevice = _connectingDevice!;
        setState(() => _connectingDevice = null);

        if (event['accepted'] == true) {
          // Navigate to the chat/transfer screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(device: respondingDevice),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection declined by user.')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to a Device'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isDiscovering ? null : _refreshDevices,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isDiscovering)
            const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.wifi,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Scanning for nearby devices...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<Device>(
              stream: _networkService.deviceStream,
              builder: (context, snapshot) {
                final devices = _networkService.discoveredDevices;
                
                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.devices,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No devices found',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Make sure other devices are on the same network',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return DeviceCard(
                      device: device,
                      onTap: () => _onDeviceSelected(device),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onDeviceSelected(Device device) {
    setState(() {
      _connectingDevice = device;
    });
    _networkService.requestConnection(device);
    _showWaitingDialog(device);
  }

  void _showWaitingDialog(Device device) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Requesting Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Waiting for ${device.name} to accept...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _connectingDevice = null);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
