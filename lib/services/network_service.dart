// ignore_for_file: prefer_expression_function_bodies

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/device.dart';
import 'file_service.dart';

class NetworkService {
  // --- Constants for networking ---  
  static const int _networkPort = 8080; // Port for TCP communication
  static const int _discoveryPort = 8081; // Port for UDP discovery
  static const String msgTypeDiscovery = 'discovery';
  static const String msgTypeConnectionRequest = 'connection_request';
  static const String msgTypeConnectionResponse = 'connection_response';
  // --- New message types for file transfer protocol ---
  static const String msgTypeChat = 'chat_message';
  static const String msgTypeFileInfo = 'file_info';
  static const String msgTypeFileResponse = 'file_response';
  static const String msgTypeFileData = 'file_data';
  static const String msgTypeFileProgress = 'file_progress';
  static const String msgTypeFileComplete = 'file_complete';
  static const String msgTypeFileError = 'file_error';
  
  // --- Stream Controllers ---
  final StreamController<List<Device>> _deviceListController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  
  // --- State ---
  final Map<String, Device> _discoveredDevices = {};
  ServerSocket? _tcpServer;
  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  
  String? _localIpAddress;
  String _deviceId = '';
  String _deviceName = '';

  // --- Public Streams ---
  Stream<List<Device>> get deviceListStream => _deviceListController.stream;
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  String? get localIpAddress => _localIpAddress;
  int get tcpServerPort => _tcpServer?.port ?? 0;

  List<Device> get discoveredDevices => _discoveredDevices.values.toList();

  Future<void> initialize(String deviceName) async {
    _deviceName = deviceName;
    _deviceId = _generateDeviceId();
    _localIpAddress = await _getLocalIpAddress();
  }

  Future<void> startDiscovery() async {
    // Stop any previous instances to prevent resource leaks
    await stopDiscovery();

    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cleanupStaleDevices());
    await _startTcpServer(); // For actual communication (chat, files)
    await _startUdpDiscovery(); // For discovering other devices
  }

  Future<void> stopDiscovery() async {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;
    await _tcpServer?.close();
    _tcpServer = null;
  }

  Future<void> _startTcpServer() async {
    try {
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, _networkPort);
      print('TCP Server started on port: ${_tcpServer!.port}');
      
      _tcpServer!.listen((Socket client) {
        _handleTcpConnection(client);
      });
    } catch (e) {
      print('Error starting TCP server: $e');
    }
  }

  Future<void> _startUdpDiscovery() async {
    try {
      // 1. Create the UDP socket to listen for broadcasts
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen(_handleUdpPacket);
      print('UDP Discovery listener started on port $_discoveryPort');

      // 2. Start broadcasting our presence periodically
      _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (_) => _broadcastPresence());
      // Send an initial broadcast immediately
      _broadcastPresence();

    } catch (e) {
      print('Error starting UDP discovery: $e');
    }
  }

  void _broadcastPresence() {
    if (_udpSocket == null) return;

    final message = {
      'type': msgTypeDiscovery,
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'port': _tcpServer?.port ?? 0, // The port for TCP connection
      'platform': Platform.operatingSystem,
    };
    final data = utf8.encode(jsonEncode(message));
    
    // Broadcast to the local network
    try {
      _udpSocket!.send(data, InternetAddress('255.255.255.255'), _discoveryPort);
    } catch (e) {
      print('Error sending broadcast: $e');
    }
  }

  void _handleTcpConnection(Socket client) {
      print('New TCP connection from: ${client.remoteAddress}');

      List<int> buffer = [];
      bool isHeaderRead = false;

      // File transfer specific state
      IOSink? fileSink;
      File? file;
      int totalBytes = 0;
      int receivedBytes = 0;
      String transferId = '';
      String fileName = '';

      client.listen(
      (data) {
        () async { // Use an async IIFE to use await inside the listener
          if (!isHeaderRead) {
            buffer.addAll(data);
            int newlineIndex = buffer.indexOf(10); // ASCII for '\n'

            if (newlineIndex != -1) {
              isHeaderRead = true;
              final headerData = buffer.sublist(0, newlineIndex);
              final remainingData = buffer.sublist(newlineIndex + 1);

              try {
                final headerString = utf8.decode(headerData);
                final jsonData = jsonDecode(headerString) as Map<String, dynamic>;
                final type = jsonData['type'] as String?;

                if (type == msgTypeFileData) {
                  // It's a file. Set up for receiving.
                  transferId = jsonData['transferId'] as String;
                  fileName = jsonData['fileName'] as String;
                  totalBytes = jsonData['fileSize'] as int;

                  print('Receiving file: $fileName ($totalBytes bytes)');

                  final fileService = FileService();
                  final downloadsDir = await fileService.getAppSaveDirectory();
                  file = await fileService.getUniqueFile(downloadsDir, fileName);
                  fileSink = file!.openWrite();

                  // Write the first chunk of file data we already have
                  if (remainingData.isNotEmpty) {
                    fileSink!.add(remainingData);
                    receivedBytes += remainingData.length;
                    _eventController.add({'type': msgTypeFileProgress, 'transferId': transferId, 'bytesTransferred': receivedBytes, 'totalBytes': totalBytes});
                  }

                  // If the entire file was in the first packet
                  if (receivedBytes >= totalBytes && totalBytes >= 0) {
                    await fileSink?.close();
                    fileSink = null;
                    print('File received and saved: ${file!.path}');
                    _eventController.add({'type': msgTypeFileComplete, 'transferId': transferId, 'filePath': file!.path});
                    client.close();
                  }
                } else {
                  // It's a regular JSON message, not a file
                  _eventController.add(jsonData);
                  client.close(); // Close after processing one-shot message
                }
              } catch (e) {
                print('Error processing incoming TCP data: $e');
                await fileSink?.close();
                if (file != null && await file!.exists()) await file!.delete();
                client.close();
              }
            }
          } else {
            // Header has been read, this is subsequent file data
            if (fileSink != null) {
              fileSink!.add(data);
              receivedBytes += data.length;
              _eventController.add({'type': msgTypeFileProgress, 'transferId': transferId, 'bytesTransferred': receivedBytes, 'totalBytes': totalBytes});

              // Check if transfer is complete
              if (receivedBytes >= totalBytes) {
                await fileSink?.close();
                fileSink = null; // Prevent further writes
                print('File received and saved: ${file!.path}');
                _eventController.add({'type': msgTypeFileComplete, 'transferId': transferId, 'filePath': file!.path});
                client.close();
              }
            }
          }
        }();
      },
      onDone: () async {
        if (fileSink != null) {
          await fileSink?.close();
          fileSink = null;
          if (receivedBytes < totalBytes) {
            print('File transfer incomplete. Deleting partial file: $fileName');
            _eventController.add({'type': msgTypeFileError, 'transferId': transferId, 'error': 'Connection closed before transfer was complete.'});
            if (file != null && await file!.exists()) await file!.delete();
          }
        }
        client.destroy();
      },
      onError: (error) async {
        print('TCP connection error: $error');
        if (fileSink != null) {
          await fileSink?.close();
          fileSink = null;
          _eventController.add({'type': msgTypeFileError, 'transferId': transferId, 'error': error.toString()});
          if (file != null && await file!.exists()) await file!.delete();
        }
        client.destroy();
      },
      cancelOnError: true,
    );
  }


  void _handleUdpPacket(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _udpSocket?.receive();
      if (datagram == null) return;

      try {
        final message = utf8.decode(datagram.data);
        final data = jsonDecode(message) as Map<String, dynamic>;

        if (data['type'] == msgTypeDiscovery) {
          final deviceId = data['deviceId'] as String;
          
          // Ignore our own broadcast
          if (deviceId == _deviceId) return;

          final device = Device(
            id: deviceId,
            name: data['deviceName'] as String,
            ipAddress: datagram.address.address, // The IP of the sender
            port: data['port'] as int, // The TCP port from the payload
            platform: data['platform'] as String,
            lastSeen: DateTime.now(),
          );

          // Add or update the device in our list
          if (!_discoveredDevices.containsKey(device.id) || _discoveredDevices[device.id] != device) {
            _discoveredDevices[device.id] = device;
            _deviceListController.add(discoveredDevices); // Emit the updated list
            print('Discovered/Updated device via UDP: ${device.name} (${device.ipAddress})');
          }
        }
      } catch (e) { /* Ignore malformed packets */ }
    }
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    final List<String> staleDeviceIds = [];
    _discoveredDevices.forEach((id, device) {
      if (now.difference(device.lastSeen).inSeconds > 15) {
        staleDeviceIds.add(id);
      }
    });

    if (staleDeviceIds.isNotEmpty) {
      staleDeviceIds.forEach(_discoveredDevices.remove);
      // Notify listeners that the list of devices has changed.
      _deviceListController.add(discoveredDevices);
      print('Removed stale devices: $staleDeviceIds');
    }
  }

  // Sends a one-shot message. Connects, sends, and closes.
  Future<void> sendMessage(Device targetDevice, Map<String, dynamic> data) async {
    // Add local device info for the receiver to identify the sender
    if (data['deviceInfo'] == null) {
      data['deviceInfo'] = {
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'ipAddress': _localIpAddress,
        'port': _tcpServer?.port ?? 0,
        'platform': Platform.operatingSystem,
      };
    }

    Socket? socket;
    try {
      // Always create a new connection. This is less efficient for chat but more
      // robust and matches the server's one-shot message handling.
      socket = await Socket.connect(targetDevice.ipAddress, targetDevice.port);
      socket.write(jsonEncode(data) + '\n');
      await socket.flush();
    } catch (e) {
      print('Error sending message to ${targetDevice.name}: $e');
      rethrow; // Rethrow to let the caller handle it (e.g., show a SnackBar)
    } finally {
      socket?.close();
    }
  }

  // Sends a one-time connection request.
  Future<void> requestConnection(Device targetDevice) async {
    try {
      final socket = await Socket.connect(targetDevice.ipAddress, targetDevice.port);
      final request = {
        'type': msgTypeConnectionRequest,
        'deviceInfo': {
          'deviceId': _deviceId,
          'deviceName': _deviceName,
          'ipAddress': _localIpAddress,
          'port': _tcpServer?.port ?? 0,
          'platform': Platform.operatingSystem,
        }
      };
      socket.write(jsonEncode(request) + '\n');
      await socket.flush();
      socket.close();
    } catch (e) {
      print('Error sending connection request: $e');
    }
  }

  // Sends a one-time response to a connection request.
  Future<void> respondToConnection(Device targetDevice, bool accepted) async {
    try {
      final socket = await Socket.connect(targetDevice.ipAddress, targetDevice.port);
      final response = {
        'type': msgTypeConnectionResponse,
        'accepted': accepted,
        'deviceInfo': { 'deviceId': _deviceId, 'deviceName': _deviceName }
      };
      socket.write(jsonEncode(response) + '\n');
      await socket.flush();
      socket.close();
    } catch (e) {
      print('Error sending connection response: $e');
    }
  }

  // This method is for sending the actual file bytes over a NEW socket connection.
  Future<void> sendFile(Device targetDevice, File file, String transferId, Function(int, int) onProgress) async {
    Socket? socket;
    try {
      socket = await Socket.connect(targetDevice.ipAddress, targetDevice.port);

      // 1. Send file metadata first
      final header = {
        'type': msgTypeFileData,
        'transferId': transferId,
        'fileName': file.path.split('/').last,
        'fileSize': await file.length(),
      };
      socket.write(jsonEncode(header) + '\n'); // Use newline as a delimiter
      await socket.flush();

      // 2. Send file content
      int totalBytes = header['fileSize'] as int;
      int bytesSent = 0;
      await for (var chunk in file.openRead()) {
        socket.add(chunk);
        bytesSent += chunk.length;
        onProgress(bytesSent, totalBytes);
        // Optional: slow down the stream to see progress
        // await Future.delayed(Duration(milliseconds: 10));
      }

      // All bytes have been passed to the socket. Flush the socket to ensure
      // the OS sends any buffered data, then gracefully close the connection
      // and wait for the process to complete.
      await socket.flush();
      await socket.close();

      print('File sent and socket closed successfully: $transferId');

    } catch (e) {
      print('Error sending file ($transferId): $e');
      socket?.destroy(); // On error, close immediately without grace.
      rethrow;
    }
  }


  // This method is for establishing the *actual* persistent connection for chat/transfer.
  Future<Socket?> connectToDevice(Device device) async {
    try {
      final socket = await Socket.connect(device.ipAddress, device.port);
      return socket;
    } catch (e) {
      print('Error connecting to device: $e');
      return null;
    }
  }

  Future<String?> _getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      return await info.getWifiIP();
    } catch (e) {
      print('Error getting local IP: $e');
      return null;
    }
  }

  String _generateDeviceId() {
    final random = Random();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  void dispose() {
    stopDiscovery();
    _deviceListController.close();
    _eventController.close();
  }
}
