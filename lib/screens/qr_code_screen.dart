import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:convert';

class QRCodeScreen extends StatefulWidget {
  const QRCodeScreen({super.key});

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  String _qrData = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateQrData();
  }

  Future<void> _generateQrData() async {
    try {
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      final deviceName = settingsService.deviceName;
      final port = settingsService.port;
      String? deviceId = settingsService.deviceId;

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = DateTime.now().millisecondsSinceEpoch.toString();
        await settingsService.setDeviceId(deviceId);
      }

      final wifiIP = await NetworkInfo().getWifiIP();

      if (wifiIP != null) {
        final data = {
          'id': deviceId,
          'name': deviceName,
          'ipAddress': wifiIP,
          'port': port,
        };
        setState(() {
          _qrData = jsonEncode(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _qrData = 'Error: No WiFi connection found. Please connect to WiFi.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _qrData = 'Error: Could not generate QR code. ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _qrData = 'Loading...';
              });
              _generateQrData();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating QR code...'),
                  ],
                )
              else if (_qrData.startsWith('Error'))
                Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _qrData,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _qrData = 'Loading...';
                        });
                        _generateQrData();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Scan this QR code to connect',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Other devices can scan this code to connect to you instantly',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
