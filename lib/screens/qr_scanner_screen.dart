// ignore_for_file: prefer_expression_function_bodies

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/discovery_service.dart';
import 'dart:convert';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isProcessing = false; // Prevent multiple scans

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            color: Colors.white,
            icon: _isScanning ? const Icon(Icons.flash_on) : const Icon(Icons.flash_off),
            iconSize: 32.0,
            onPressed: () {
              setState(() {
                _isScanning = !_isScanning;
                cameraController.toggleTorch();
              });
            },
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.camera_rear),
            iconSize: 32.0,
            onPressed: () {
              cameraController.switchCamera();
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? rawValue = barcodes.first.rawValue;
            if (rawValue != null) {
              _handleQrCode(rawValue);
              cameraController.stop(); // Stop scanning after successful detection
            }
          }
        },
      ),
    );
  }

  void _handleQrCode(String qrData) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final Map<String, dynamic> data = jsonDecode(qrData);
      
      if (!data.containsKey('id') || !data.containsKey('name') || 
          !data.containsKey('ipAddress') || !data.containsKey('port')) {
        throw Exception('Invalid QR code format');
      }
      
      final String id = data['id'];
      final String name = data['name'];
      final String ipAddress = data['ipAddress'];
      final int port = data['port'];

      final discoveryService = Provider.of<DiscoveryService>(context, listen: false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Connecting to device...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      await discoveryService.connectViaQR(ipAddress, port, id, name);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully connected to $name'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isProcessing = false;
      });
      cameraController.start();
    }
  }
}
