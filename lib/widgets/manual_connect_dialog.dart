import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManualConnectDialog extends StatefulWidget {
  final Function(String ipAddress, int port) onConnect;

  const ManualConnectDialog({
    super.key,
    required this.onConnect,
  });

  @override
  State<ManualConnectDialog> createState() => _ManualConnectDialogState();
}

class _ManualConnectDialogState extends State<ManualConnectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  bool _isConnecting = false;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Connect'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the IP address and port of the device you want to connect to.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
                prefixIcon: Icon(Icons.wifi),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an IP address';
                }
                
                final parts = value.split('.');
                if (parts.length != 4) {
                  return 'Invalid IP address format';
                }
                
                for (final part in parts) {
                  final num = int.tryParse(part);
                  if (num == null || num < 0 || num > 255) {
                    return 'Invalid IP address';
                  }
                }
                
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '8080',
                prefixIcon: Icon(Icons.settings_ethernet),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a port number';
                }
                
                final port = int.tryParse(value);
                if (port == null || port < 1 || port > 65535) {
                  return 'Port must be between 1 and 65535';
                }
                
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _handleConnect,
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }

  Future<void> _handleConnect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      final ipAddress = _ipController.text.trim();
      final port = int.parse(_portController.text.trim());
      
      await widget.onConnect(ipAddress, port);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }
}
