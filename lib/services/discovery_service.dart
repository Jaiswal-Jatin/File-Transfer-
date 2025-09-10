// ignore_for_file: avoid_catches_without_on_clauses, omit_local_variable_types, prefer_expression_function_bodies

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart'; // Import uuid package
import '../models/device.dart';
import 'settings_service.dart';

class DiscoveryService extends ChangeNotifier {
  static const String _serviceType = '_p2pfileshare._tcp';
  static const int _discoveryPort = 4040; // Changed to port 4040 as specified
  
  final List<Device> _discoveredDevices = [];
  final List<Device> _connectedDevices = [];
  final MDnsClient _mdnsClient = MDnsClient();
  final Uuid _uuid = const Uuid();
  ServerSocket? _serverSocket;
  Timer? _discoveryTimer;
  Timer? _cleanupTimer;
  bool _isDiscovering = false;
  bool _isAdvertising = false;
  SettingsService? _settingsService;
  String? _ownDeviceId;
  
  final Map<String, Device> _devicesByIp = {};

  Future<bool> Function(Device)? _connectionDialogCallback;

  List<Device> get discoveredDevices {
    final connectedIds = _connectedDevices.map((d) => d.id).toSet();
    return _discoveredDevices.where((device) => 
      !connectedIds.contains(device.id) && 
      device.id != _ownDeviceId
    ).toList();
  }

  List<Device> get connectedDevices => List.unmodifiable(_connectedDevices);
  bool get isDiscovering => _isDiscovering;
  bool get isAdvertising => _isAdvertising;

  void setSettingsService(SettingsService settingsService) {
    _settingsService = settingsService;
    _ownDeviceId = settingsService.deviceId;
  }

  void setConnectionDialogCallback(Future<bool> Function(Device) callback) {
    _connectionDialogCallback = callback;
  }

  Future<void> connectToDevice(Device device) async {
    try {
      if (_isDiscovering) {
        await stopDiscovery();
      }
      
      final socket = await Socket.connect(device.ipAddress, device.port, 
          timeout: const Duration(seconds: 5));
      
      final connectionRequest = jsonEncode({
        'type': 'connection_request',
        'deviceId': _ownDeviceId,
        'deviceName': _settingsService?.deviceName ?? 'Unknown',
        'ipAddress': await NetworkInfo().getWifiIP(),
        'port': _settingsService?.port ?? _discoveryPort,
      });
      
      socket.write(connectionRequest);
      await socket.flush();
      
      final completer = Completer<String>();
      late StreamSubscription subscription;
      
      subscription = socket.listen((List<int> data) {
        if (!completer.isCompleted) {
          completer.complete(utf8.decode(data));
          subscription.cancel();
        }
      });
      
      final responseData = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );
      
      final response = jsonDecode(responseData);
      
      if (response['type'] == 'connection_accepted') {
        final connectedDevice = device.copyWith(isConnected: true);
        _addToConnectedDevices(connectedDevice);
        _discoveredDevices.removeWhere((d) => d.id == device.id);
        _devicesByIp.remove(device.ipAddress);
        debugPrint('Connection accepted by ${device.name}');
      } else {
        throw Exception('Connection rejected by ${device.name}');
      }
      
      socket.close();
    } catch (e) {
      debugPrint('Failed to connect to device: $e');
      throw Exception('Failed to connect to ${device.name}: ${e.toString()}');
    }
  }

  Future<void> disconnectDevice(Device device) async {
    try {
      _connectedDevices.removeWhere((d) => d.id == device.id);
      notifyListeners();
      
      // Notify the other device about disconnection
      final socket = await Socket.connect(device.ipAddress, device.port, 
          timeout: const Duration(seconds: 3));
      
      final disconnectionRequest = jsonEncode({
        'type': 'disconnection_request',
        'deviceId': _ownDeviceId,
        'deviceName': _settingsService?.deviceName ?? 'Unknown',
      });
      
      socket.write(disconnectionRequest);
      await socket.flush();
      socket.close();
      
      debugPrint('Disconnected from device: ${device.name}');
    } catch (e) {
      // Device already removed from list above
      debugPrint('Disconnected device locally: ${device.name}');
    }
  }

  void _addToConnectedDevices(Device device) {
    if (device.id == _ownDeviceId) return;
    
    final existingIndex = _connectedDevices.indexWhere((d) => d.id == device.id);
    if (existingIndex >= 0) {
      _connectedDevices[existingIndex] = device;
    } else {
      _connectedDevices.add(device);
    }
    notifyListeners();
  }

  Future<void> refreshDevices() async {
    _discoveredDevices.clear();
    _devicesByIp.clear();
    notifyListeners();
    
    if (_isDiscovering) {
      await _performDiscovery();
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    
    _isDiscovering = true;
    notifyListeners();

    try {
      await _mdnsClient.start();
      
      _discoveryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _performDiscovery();
      });
      
      _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _cleanupStaleDevices();
      });
      
      await _performDiscovery();
      
    } catch (e) {
      debugPrint('Discovery error: $e');
      _isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _discoveryTimer?.cancel();
    _cleanupTimer?.cancel();
    
    try {
      _mdnsClient.stop();
    } catch (e) {
      debugPrint('Error stopping mDNS client: $e');
    }
    
    notifyListeners();
  }

  Future<void> startAdvertising() async {
    if (_isAdvertising || _settingsService == null) return;
    
    _isAdvertising = true;
    notifyListeners();

    try {
      final deviceName = _settingsService!.deviceName;
      final port = 4040; // Fixed port to 4040 for consistency
      String? deviceId = _settingsService!.deviceId;

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = _uuid.v4();
        await _settingsService!.setDeviceId(deviceId);
      }
      
      _ownDeviceId = deviceId;
      
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP == null) {
        throw Exception('No WiFi connection found');
      }

      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 4040);
      _serverSocket!.listen((Socket clientSocket) {
        clientSocket.listen((List<int> data) async {
          try {
            final request = jsonDecode(utf8.decode(data));
            
            if (request['type'] == 'discovery') {
              final response = jsonEncode({
                'id': deviceId,
                'name': deviceName,
                'ipAddress': wifiIP,
                'port': 4040, // Return port 4040
                'type': 'response',
              });
              clientSocket.write(response);
              await clientSocket.flush();
            } else if (request['type'] == 'connection_request') {
              await _handleConnectionRequest(request, clientSocket);
            } else if (request['type'] == 'disconnection_request') {
              _handleDisconnectionRequest(request);
            }
          } catch (e) {
            debugPrint('Error handling request: $e');
          } finally {
            clientSocket.close();
          }
        });
      });
      
      debugPrint('Started advertising as: $deviceName ($wifiIP:4040) with ID: $deviceId');
    } catch (e) {
      debugPrint('Advertising error: $e');
      _isAdvertising = false;
      notifyListeners();
    }
  }

  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;
    
    _isAdvertising = false;
    
    try {
      await _serverSocket?.close();
      _serverSocket = null;
      debugPrint('Stopped advertising');
    } catch (e) {
      debugPrint('Error stopping advertising: $e');
    }
    
    notifyListeners();
  }

  Future<void> _handleConnectionRequest(Map<String, dynamic> request, Socket socket) async {
    try {
      final device = Device(
        id: request['deviceId'],
        name: request['deviceName'],
        ipAddress: request['ipAddress'],
        port: request['port'],
        isConnected: false,
        lastSeen: DateTime.now(),
      );
      
      final shouldConnect = await _showConnectionDialog(device);
      
      if (shouldConnect) {
        if (_isDiscovering) {
          await stopDiscovery();
        }
        
        _addToConnectedDevices(device.copyWith(isConnected: true));
        _discoveredDevices.removeWhere((d) => d.id == device.id);
        _devicesByIp.remove(device.ipAddress);
        
        final response = jsonEncode({
          'type': 'connection_accepted',
          'deviceId': _ownDeviceId,
          'deviceName': _settingsService?.deviceName ?? 'Unknown',
        });
        
        socket.write(response);
      } else {
        final response = jsonEncode({
          'type': 'connection_rejected',
          'deviceId': _ownDeviceId,
          'deviceName': _settingsService?.deviceName ?? 'Unknown',
        });
        
        socket.write(response);
      }
      
      await socket.flush();
    } catch (e) {
      debugPrint('Error handling connection request: $e');
    }
  }

  Future<bool> _showConnectionDialog(Device device) async {
    if (_connectionDialogCallback != null) {
      return await _connectionDialogCallback!(device);
    }
    // Default to accepting connections if no callback is set
    return true;
  }

  void _handleDisconnectionRequest(Map<String, dynamic> request) {
    final deviceId = request['deviceId'];
    final removedDevice = _connectedDevices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => Device(
        id: deviceId,
        name: request['deviceName'] ?? 'Unknown',
        ipAddress: '',
        port: 0,
        isConnected: false,
        lastSeen: DateTime.now(),
      ),
    );
    
    _connectedDevices.removeWhere((d) => d.id == deviceId);
    notifyListeners();
    debugPrint('Device ${request['deviceName']} disconnected');
  }

  Future<void> _performDiscovery() async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP != null) {
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
          
          final List<Future<void>> scanTasks = [];
          
          for (int i = 1; i <= 254; i++) {
            final targetIp = '$subnet.$i';
            if (targetIp == wifiIP) continue; // Don't scan our own IP
            
            scanTasks.add(_scanDevice(targetIp));
          }
          
          await Future.wait(scanTasks).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Discovery scan timed out');
              return <void>[];
            },
          );
        }
      }

      await _performMdnsDiscovery();

    } catch (e) {
      debugPrint('Discovery error: $e');
    }
  }

  Future<void> _scanDevice(String targetIp) async {
    try {
      final socket = await Socket.connect(
        targetIp, 
        4040, // Scan on port 4040
        timeout: const Duration(milliseconds: 2000)
      );
      
      final request = jsonEncode({
        'type': 'discovery',
        'deviceName': _settingsService?.deviceName ?? 'Unknown',
        'deviceId': _ownDeviceId,
      });
      
      socket.write(request);
      await socket.flush();
      
      final List<int> responseBytes = [];
      await for (final data in socket) {
        responseBytes.addAll(data);
        break; // Get first response chunk
      }
      
      final responseData = utf8.decode(responseBytes);
      final data = jsonDecode(responseData);
      
      if (data['id'] != _ownDeviceId && data['type'] == 'response') {
        final device = Device(
          id: data['id'] ?? targetIp,
          name: data['name'] ?? 'Unknown Device',
          ipAddress: targetIp,
          port: 4040, // Use port 4040
          isConnected: false,
          lastSeen: DateTime.now(),
        );
        _addOrUpdateDevice(device);
      }
      
      socket.close();
    } catch (e) {
      // Device not found or connection failed - this is normal
    }
  }

  Future<void> _performMdnsDiscovery() async {
    try {
      await for (final PtrResourceRecord ptr in _mdnsClient
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(_serviceType))) {
        
        await for (final SrvResourceRecord srv in _mdnsClient
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
          
          await for (final TxtResourceRecord txt in _mdnsClient
              .lookup<TxtResourceRecord>(ResourceRecordQuery.text(ptr.domainName))) {
            
            final deviceInfo = _parseTxtRecord(txt.text);
            if (deviceInfo != null && deviceInfo['id'] != _ownDeviceId) {
              final device = Device(
                id: deviceInfo['id'] ?? srv.target,
                name: deviceInfo['name'] ?? 'Unknown Device',
                ipAddress: srv.target,
                port: srv.port,
                isConnected: false,
                lastSeen: DateTime.now(),
              );
              
              _addOrUpdateDevice(device);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('mDNS discovery error: $e');
    }
  }

  Map<String, String>? _parseTxtRecord(String txtData) {
    try {
      // Parse TXT record data
      final parts = txtData.split('&');
      final Map<String, String> result = {};
      
      for (final part in parts) {
        final keyValue = part.split('=');
        if (keyValue.length == 2) {
          result[keyValue[0]] = keyValue[1];
        }
      }
      
      return result;
    } catch (e) {
      return null;
    }
  }

  void _addOrUpdateDevice(Device device) {
    if (device.id == _ownDeviceId) {
      return;
    }
    
    // Check if device with same IP already exists
    final existingDevice = _devicesByIp[device.ipAddress];
    if (existingDevice != null) {
      // Update existing device with latest info
      final updatedDevice = existingDevice.copyWith(
        name: device.name,
        port: device.port,
        lastSeen: DateTime.now(),
      );
      
      final existingIndex = _discoveredDevices.indexWhere((d) => d.ipAddress == device.ipAddress);
      if (existingIndex >= 0) {
        _discoveredDevices[existingIndex] = updatedDevice;
      }
      _devicesByIp[device.ipAddress] = updatedDevice;
    } else {
      // Add new device
      _discoveredDevices.add(device);
      _devicesByIp[device.ipAddress] = device;
      debugPrint('Added device: ${device.name} (${device.ipAddress}:${device.port})');
    }
    
    notifyListeners();
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    _discoveredDevices.removeWhere((device) {
      final isStale = now.difference(device.lastSeen).inMinutes > 2;
      if (isStale) {
        _devicesByIp.remove(device.ipAddress);
      }
      return isStale;
    });
    notifyListeners();
  }

  Future<void> addManualDevice(String ipAddress, int port) async {
    try {
      final socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 5));
      
      final request = jsonEncode({
        'type': 'discovery',
        'deviceName': _settingsService?.deviceName ?? 'Unknown',
        'deviceId': _ownDeviceId,
      });
      
      socket.write(request);
      await socket.flush();
      
      final List<int> responseBytes = [];
      await for (final data in socket) {
        responseBytes.addAll(data);
        break; // Get first response chunk
      }
      
      final responseData = utf8.decode(responseBytes);
      final data = jsonDecode(responseData);
      
      if (data['id'] == _ownDeviceId) {
        socket.close();
        throw Exception('Cannot connect to your own device');
      }
      
      final device = Device(
        id: data['id'] ?? ipAddress,
        name: data['name'] ?? 'Manual Device',
        ipAddress: ipAddress,
        port: port,
        isConnected: false, // Set as discovered, not connected initially
        lastSeen: DateTime.now(),
      );
      
      _addOrUpdateDevice(device);
      socket.close();
      
    } catch (e) {
      debugPrint('Manual device connection error: $e');
      throw Exception('Could not connect to device at $ipAddress:$port - ${e.toString()}');
    }
  }

  void removeDevice(String deviceId) {
    _discoveredDevices.removeWhere((device) => device.id == deviceId);
    notifyListeners();
  }

  Future<Device> connectViaQR(String ipAddress, int port, String deviceId, String deviceName) async {
    try {
      if (_isDiscovering) {
        await stopDiscovery();
      }
      
      final device = Device(
        id: deviceId,
        name: deviceName,
        ipAddress: ipAddress,
        port: port,
        isConnected: false,
        lastSeen: DateTime.now(),
      );
      
      // Auto-connect without confirmation for QR codes
      await connectToDevice(device);
      
      return device.copyWith(isConnected: true);
    } catch (e) {
      debugPrint('QR connection error: $e');
      throw Exception('Failed to connect via QR code: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    stopDiscovery();
    stopAdvertising();
    super.dispose();
  }
}
