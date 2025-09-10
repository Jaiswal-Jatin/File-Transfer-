import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';
import '../screens/chat_screen.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;
  final VoidCallback? onDisconnect; // Added disconnect callback

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.onDisconnect, // Added disconnect callback parameter
  });

  @override
  Widget build(BuildContext context) {
    final timeSinceLastSeen = DateTime.now().difference(device.lastSeen);
    final isRecent = timeSinceLastSeen.inMinutes < 2;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: device.isConnected
                    ? Colors.green.withOpacity(0.2)
                    : isRecent 
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getDeviceIcon(),
                  color: device.isConnected
                    ? Colors.green
                    : isRecent 
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Device Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (device.isConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Connected',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${device.ipAddress}:${device.port}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: device.isConnected 
                              ? Colors.green 
                              : isRecent ? Colors.green : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.isConnected 
                            ? 'Connected'
                            : isRecent ? 'Online' : 'Last seen ${_formatTimeSince(timeSinceLastSeen)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: device.isConnected 
                              ? Colors.green 
                              : isRecent ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!device.isConnected)
                    IconButton(
                      onPressed: () => _connectToDevice(context),
                      icon: const Icon(Icons.link),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      tooltip: 'Connect to ${device.name}',
                    ),
                  if (device.isConnected && onDisconnect != null) ...[
                    IconButton(
                      onPressed: onDisconnect,
                      icon: const Icon(Icons.link_off),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                      ),
                      tooltip: 'Disconnect from ${device.name}',
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    onPressed: onTap,
                    icon: const Icon(Icons.chat),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    tooltip: 'Chat with ${device.name}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _connectToDevice(BuildContext context) async {
    try {
      final discoveryService = context.read<DiscoveryService>();
      await discoveryService.connectToDevice(device);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(device: device),
      ),
    );
  }

  IconData _getDeviceIcon() {
    final deviceName = device.name.toLowerCase();
    
    if (deviceName.contains('iphone') || deviceName.contains('ios')) {
      return Icons.phone_iphone;
    } else if (deviceName.contains('android')) {
      return Icons.phone_android;
    } else if (deviceName.contains('mac') || deviceName.contains('macbook')) {
      return Icons.laptop_mac;
    } else if (deviceName.contains('windows') || deviceName.contains('pc')) {
      return Icons.computer;
    } else if (deviceName.contains('tablet') || deviceName.contains('ipad')) {
      return Icons.tablet;
    }
    
    return Icons.devices;
  }

  String _formatTimeSince(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'just now';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ago';
    } else {
      return '${duration.inDays}d ago';
    }
  }
}
