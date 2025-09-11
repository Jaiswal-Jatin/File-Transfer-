import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/device.dart';
import 'file_service.dart';

class NetworkService {
  // --- Constants for networking ---
  static const int _discoveryPort = 8888; // Port for UDP broadcast
  static const String _serviceType = '_p2pshare._tcp'; // For mDNS
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
  final StreamController<Device> _deviceController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  final Map<String, Device> _discoveredDevices = {};
  
  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  MDnsClient? _mdnsClient;
  Timer? _broadcastTimer;
  
  String? _localIpAddress;
  String _deviceId = '';
  String _deviceName = '';

  // --- Public Streams ---
  Stream<Device> get deviceStream => _deviceController.stream;
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
    await _startUdpBroadcast();
    // mDNS discovery is not fully implemented in this snippet,
    // but this is where you would start it.
    await _startMdnsDiscovery();
    await _startTcpServer();
  }

  Future<void> stopDiscovery() async {
    _broadcastTimer?.cancel();
    _udpSocket?.close();
    await _tcpServer?.close();
    _mdnsClient?.stop();
    _discoveredDevices.clear();
    // Do not close controllers here if the service is meant to be long-lived.
  }

  Future<void> _startUdpBroadcast() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
      _udpSocket!.broadcastEnabled = true;

      // Listen for incoming broadcasts
      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            _handleIncomingBroadcast(datagram);
          }
        }
      });

      // Send periodic broadcasts
      _broadcastTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _sendBroadcast();
      });

    } catch (e) {
      print('Error starting UDP broadcast: $e');
    }
  }

  Future<void> _startMdnsDiscovery() async {
    try {
      _mdnsClient = MDnsClient();
      await _mdnsClient!.start();

      // Advertise our service
      await _mdnsClient!.start();
      
    } catch (e) {
      print('Error starting mDNS discovery: $e');
    }
  }

  Future<void> _startTcpServer() async {
    try {
      _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      print('TCP Server started on port: ${_tcpServer!.port}');
      
      _tcpServer!.listen((Socket client) {
        _handleTcpConnection(client);
      });
    } catch (e) {
      print('Error starting TCP server: $e');
    }
  }

  void _sendBroadcast() {
    if (_udpSocket == null || _localIpAddress == null) return;

    final message = jsonEncode({
      'type': msgTypeDiscovery,
      'deviceId': _deviceId,
      'deviceName': _deviceName,
      'ipAddress': _localIpAddress,
      'port': _tcpServer?.port ?? 0,
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final data = utf8.encode(message);
    _udpSocket!.send(data, InternetAddress('255.255.255.255'), _discoveryPort);
  }

  void _handleIncomingBroadcast(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final data = jsonDecode(message);

      if (data['type'] == msgTypeDiscovery && data['deviceId'] != _deviceId) {
        final device = Device(
          id: data['deviceId'],
          name: data['deviceName'],
          ipAddress: data['ipAddress'],
          port: data['port'],
          platform: data['platform'],
          lastSeen: DateTime.now(),
        );

        _discoveredDevices[device.id] = device;
        _deviceController.add(device);
      }
    } catch (e) {
      print('Error handling broadcast: $e');
    }
  }

  void _handleTcpConnection(Socket client) {
    print('New TCP connection from: ${client.remoteAddress}');
    
    StreamSubscription? subscription;

    subscription = client.listen(
      (data) {
        // Once we have a subscription, we can cancel it to take over the stream.
        subscription?.cancel();

        // Manually find the first newline character.
        int newlineIndex = -1;
        for (int i = 0; i < data.length; i++) {
          if (data[i] == 10) { // ASCII for '\n'
            newlineIndex = i;
            break;
          }
        }

        if (newlineIndex != -1) {
          // We found the header in the first chunk.
          final headerData = data.sublist(0, newlineIndex);
          final headerString = utf8.decode(headerData);
          
          try {
            final jsonData = jsonDecode(headerString) as Map<String, dynamic>;
            final type = jsonData['type'] as String?;

            if (type == msgTypeFileData || type == 'file_transfer_start') {
              // This is a file transfer. The rest of the stream is bytes.
              final firstChunk = data.sublist(newlineIndex + 1);
              _handleIncomingFile(client, jsonData, firstChunk);
            } else {
              // This is a regular control message.
              _eventController.add(jsonData);
              client.close();
            }
          } catch (e) {
            print('Error decoding JSON from TCP stream: $e. Raw line: "$headerString"');
            client.close();
          }
        } else {
          // The first chunk didn't contain a full header, this is unexpected for our simple protocol.
          // This would require more robust buffering, but for now we'll assume the header fits in the first packet.
          print('Error: Did not find header in first TCP packet.');
          client.close();
        }
      },
      onDone: () {
        client.close();
      },
      onError: (error) {
        print('TCP connection error: $error');
        client.close();
      },
      cancelOnError: true,
    );
  }

  // New method to handle the file stream
  Future<void> _handleIncomingFile(Socket client, Map<String, dynamic> header, List<int> firstChunk) async {
    final transferId = header['transferId'] as String;
    final fileName = header['fileName'] as String;
    final fileSize = header['fileSize'] as int;

    print('Receiving file: $fileName ($fileSize bytes)');

    final fileService = FileService();
    IOSink? sink;

    try {
      final downloadsDir = await fileService.getDownloadsDirectory();
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final file = File('${downloadsDir.path}/$fileName');
      sink = file.openWrite();
      
      // Write the first chunk that we already have
      sink.add(firstChunk);
      int totalReceived = firstChunk.length;
      _eventController.add({'type': msgTypeFileProgress, 'transferId': transferId, 'bytesTransferred': totalReceived, 'totalBytes': fileSize});
      
      await client.listen(
        (data) {
          // sink can be null if an error occurs before this callback
          sink!.add(data);
          totalReceived += data.length;
          _eventController.add({'type': msgTypeFileProgress, 'transferId': transferId, 'bytesTransferred': totalReceived, 'totalBytes': fileSize});
        },
        onDone: () async {
          await sink?.close();
          print('File received and saved: ${file.path}');
          _eventController.add({'type': msgTypeFileComplete, 'transferId': transferId, 'filePath': file.path});
          client.close();
        },
        onError: (error) {
          sink?.close();
          client.close();
          _eventController.add({'type': msgTypeFileError, 'transferId': transferId, 'error': error.toString()});
        },
        cancelOnError: true,
      ).asFuture();

    } catch (e) {
      print('Error setting up file receive: $e');
      await sink?.close();
      client.close();
      _eventController.add({'type': msgTypeFileError, 'transferId': transferId, 'error': e.toString()});
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

      await socket.flush();
      print('File sent successfully: $transferId');

    } catch (e) {
      print('Error sending file ($transferId): $e');
      // You should also notify the UI about the error.
    } finally {
      socket?.close();
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
    _deviceController.close();
    _eventController.close();
  }
}
