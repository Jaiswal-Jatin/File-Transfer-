// ignore_for_file: prefer_expression_function_bodies

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _deviceNameController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsService>();
      _deviceNameController.text = settings.deviceName;
      _portController.text = settings.port.toString();
    });
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Device Settings Section
              SettingsSection(
                title: 'Device Settings',
                children: [
                  SettingsTile(
                    icon: Icons.smartphone,
                    title: 'Device Name',
                    subtitle: 'How others see your device',
                    trailing: Text(
                      settings.deviceName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => _showDeviceNameDialog(),
                  ),
                  SettingsTile(
                    icon: Icons.visibility,
                    title: 'Make Discoverable',
                    subtitle: 'Allow other devices to find you',
                    trailing: Switch(
                      value: settings.isDiscoverable,
                      onChanged: (value) async {
                        await settings.setDiscoverable(value);
                        final discoveryService = context.read<DiscoveryService>();
                        if (value) {
                          await discoveryService.startAdvertising();
                        } else {
                          await discoveryService.stopAdvertising();
                        }
                      },
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.settings_ethernet,
                    title: 'Port',
                    subtitle: 'Network port for connections',
                    trailing: Text(
                      settings.port.toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => _showPortDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Transfer Settings Section
              SettingsSection(
                title: 'Transfer Settings',
                children: [
                  SettingsTile(
                    icon: Icons.auto_awesome,
                    title: 'Auto Accept Files',
                    subtitle: 'Automatically accept incoming files',
                    trailing: Switch(
                      value: settings.autoAccept,
                      onChanged: (value) {
                        if (value) {
                          _showAutoAcceptWarning(() {
                            settings.setAutoAccept(true);
                          });
                        } else {
                          settings.setAutoAccept(false);
                        }
                      },
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.folder,
                    title: 'Default Save Folder',
                    subtitle: settings.defaultSaveFolder.isEmpty 
                        ? 'Downloads folder' 
                        : settings.defaultSaveFolder,
                    onTap: () => _showSaveFolderDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Appearance Section
              SettingsSection(
                title: 'Appearance',
                children: [
                  SettingsTile(
                    icon: settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    title: 'Dark Mode',
                    subtitle: 'Use dark theme',
                    trailing: Switch(
                      value: settings.isDarkMode,
                      onChanged: (value) => settings.setDarkMode(value),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Privacy & Security Section
              SettingsSection(
                title: 'Privacy & Security',
                children: [
                  SettingsTile(
                    icon: Icons.history,
                    title: 'Clear Transfer History',
                    subtitle: 'Remove all completed transfers',
                    onTap: () => _showClearHistoryDialog(),
                  ),
                  SettingsTile(
                    icon: Icons.visibility_off,
                    title: 'Stop Discovery',
                    subtitle: 'Hide from all devices temporarily',
                    onTap: () => _stopAllDiscovery(),
                  ),
                  SettingsTile(
                    icon: Icons.delete_sweep,
                    title: 'Reset All Settings',
                    subtitle: 'Restore default settings',
                    onTap: () => _showResetDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // About Section
              SettingsSection(
                title: 'About',
                children: [
                  SettingsTile(
                    icon: Icons.info,
                    title: 'About P2P File Share',
                    subtitle: 'Version, licenses, and more',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AboutScreen(),
                      ),
                    ),
                  ),
                  SettingsTile(
                    icon: Icons.help,
                    title: 'Help & Support',
                    subtitle: 'Get help using the app',
                    onTap: () => _showHelpDialog(),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  void _showDeviceNameDialog() {
    _deviceNameController.text = context.read<SettingsService>().deviceName;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This name will be visible to other devices when they discover you.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
              ),
              maxLength: 30,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _deviceNameController.text.trim();
              if (newName.isNotEmpty) {
                await context.read<SettingsService>().setDeviceName(newName);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPortDialog() {
    _portController.text = context.read<SettingsService>().port.toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Port'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change the port used for file transfers. Restart the app after changing.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port (1-65535)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final portText = _portController.text.trim();
              final port = int.tryParse(portText);
              if (port != null && port >= 1 && port <= 65535) {
                await context.read<SettingsService>().setPort(port);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Port updated. Please restart the app.'),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid port number (1-65535)'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAutoAcceptWarning(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Security Warning'),
          ],
        ),
        content: const Text(
          'Auto-accepting files can be a security risk. Only enable this if you trust all devices on your network. Files will be saved automatically without your confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enable Anyway'),
          ),
        ],
      ),
    );
  }

  void _showSaveFolderDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Folder picker not yet implemented'),
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Transfer History'),
        content: const Text(
          'This will remove all completed and failed transfers from the history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TransferService>().clearHistory();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transfer history cleared'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _stopAllDiscovery() async {
    final discoveryService = context.read<DiscoveryService>();
    await discoveryService.stopDiscovery();
    await discoveryService.stopAdvertising();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discovery stopped. You are now hidden from other devices.'),
        ),
      );
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text(
          'This will restore all settings to their default values. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<SettingsService>().clearAllSettings();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to use P2P File Share:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('1. Make sure both devices are on the same Wi-Fi network'),
              Text('2. Enable "Make Discoverable" in settings'),
              Text('3. Wait for devices to appear on the home screen'),
              Text('4. Tap a device and select files to send'),
              Text('5. Accept incoming files when prompted'),
              SizedBox(height: 16),
              Text(
                'Troubleshooting:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text('• Check Wi-Fi connection on both devices'),
              Text('• Try manual connect with IP address'),
              Text('• Restart the app if discovery fails'),
              Text('• Check firewall settings on desktop'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
