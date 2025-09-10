// ignore_for_file: avoid_catches_without_on_clauses, unawaited_futures, always_put_control_body_on_new_line, prefer_interpolation_to_compose_strings, cascade_invocations, unnecessary_lambdas

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../models/file_transfer.dart';
import 'notification_service.dart';

class TransferService extends ChangeNotifier {
  final List<FileTransfer> _transfers = [];
  final Map<String, Socket> _activeConnections = {};
  final Map<String, StreamSubscription> _transferSubscriptions = {};
  ServerSocket? _serverSocket;
  bool _isListening = false;
  
  static const int _chunkSize = 64 * 1024; // 64KB chunks
  static const _uuid = Uuid();

  List<FileTransfer> get transfers => List.unmodifiable(_transfers);
  List<FileTransfer> get ongoingTransfers => 
      _transfers.where((t) => t.status == TransferStatus.inProgress || 
                             t.status == TransferStatus.pending).toList();
  List<FileTransfer> get completedTransfers => 
      _transfers.where((t) => t.status == TransferStatus.completed || 
                             t.status == TransferStatus.failed ||
                             t.status == TransferStatus.cancelled).toList();

  bool get isListening => _isListening;

  Future<void> startListening(int port) async {
    if (_isListening) return;

    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isListening = true;
      
      _serverSocket!.listen((Socket socket) {
        _handleIncomingConnection(socket);
      });
      
      debugPrint('Transfer service listening on port $port');
      notifyListeners();
      
    } catch (e) {
      debugPrint('Failed to start transfer service: $e');
      throw Exception('Could not start transfer service on port $port');
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _serverSocket?.close();
    _serverSocket = null;
    
    // Close all active connections
    for (final socket in _activeConnections.values) {
      socket.close();
    }
    _activeConnections.clear();
    
    // Cancel all subscriptions
    for (final subscription in _transferSubscriptions.values) {
      subscription.cancel();
    }
    _transferSubscriptions.clear();
    
    notifyListeners();
  }

  Future<String> sendFile(String filePath, Device targetDevice) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final fileSize = await file.length();
    final fileName = file.path.split('/').last;
    final transferId = _uuid.v4();

    final transfer = FileTransfer(
      id: transferId,
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      device: targetDevice,
      direction: TransferDirection.sending,
      status: TransferStatus.pending,
      startTime: DateTime.now(),
    );

    _transfers.add(transfer);
    notifyListeners();

    try {
      // Connect to target device
      final socket = await Socket.connect(
        targetDevice.ipAddress, 
        targetDevice.port,
        timeout: const Duration(seconds: 10),
      );

      _activeConnections[transferId] = socket;

      // Send transfer request
      final request = {
        'type': 'transfer_request',
        'transferId': transferId,
        'fileName': fileName,
        'fileSize': fileSize,
        'deviceName': 'This Device', // Should come from settings
      };

      socket.write(jsonEncode(request) + '\n');

      // Wait for acceptance
      final response = await socket.transform(const Utf8Decoder() as StreamTransformer<Uint8List, dynamic>).first;
      final responseData = jsonDecode(response);

      if (responseData['accepted'] == true) {
        await _performFileSend(transferId, file, socket);
      } else {
        _updateTransfer(transferId, status: TransferStatus.cancelled);
        socket.close();
      }

    } catch (e) {
      debugPrint('Send file error: $e');
      _updateTransfer(transferId, 
        status: TransferStatus.failed, 
        errorMessage: e.toString()
      );
    }

    return transferId;
  }

  Future<void> _performFileSend(String transferId, File file, Socket socket) async {
    _updateTransfer(transferId, status: TransferStatus.inProgress);
    
    final fileSize = await file.length();
    int bytesSent = 0;
    final startTime = DateTime.now();
    
    try {
      final fileStream = file.openRead();
      
      await for (final chunk in fileStream) {
        socket.add(chunk);
        bytesSent += chunk.length;
        
        final progress = bytesSent / fileSize;
        final elapsed = DateTime.now().difference(startTime);
        final speed = bytesSent / elapsed.inSeconds;
        
        _updateTransfer(transferId,
          progress: progress,
          bytesTransferred: bytesSent,
          speed: speed,
        );
        
        // Small delay to prevent overwhelming the receiver
        await Future.delayed(const Duration(microseconds: 100));
      }
      
      await socket.flush();
      socket.close();
      
      _updateTransfer(transferId, 
        status: TransferStatus.completed,
        endTime: DateTime.now(),
      );
      
      NotificationService.showTransferComplete(
        _getTransfer(transferId)!.fileName, 
        true
      );
      
    } catch (e) {
      debugPrint('File send error: $e');
      _updateTransfer(transferId, 
        status: TransferStatus.failed,
        errorMessage: e.toString(),
        endTime: DateTime.now(),
      );
    }
  }

  void _handleIncomingConnection(Socket socket) {
    socket.transform(const Utf8Decoder() as StreamTransformer<Uint8List, dynamic>).listen((data) {
      try {
        final request = jsonDecode(data.trim());
        
        if (request['type'] == 'transfer_request') {
          _handleTransferRequest(socket, request);
        }
      } catch (e) {
        debugPrint('Error handling incoming connection: $e');
        socket.close();
      }
    });
  }

  void _handleTransferRequest(Socket socket, Map<String, dynamic> request) {
    final transferId = request['transferId'];
    final fileName = request['fileName'];
    final fileSize = request['fileSize'];
    final deviceName = request['deviceName'];

    // Create incoming transfer
    final device = Device(
      id: 'incoming',
      name: deviceName,
      ipAddress: socket.remoteAddress.address,
      port: socket.remotePort,
      lastSeen: DateTime.now(),
    );

    final transfer = FileTransfer(
      id: transferId,
      fileName: fileName,
      filePath: '', // Will be set when accepted
      fileSize: fileSize,
      device: device,
      direction: TransferDirection.receiving,
      status: TransferStatus.pending,
      startTime: DateTime.now(),
    );

    _transfers.add(transfer);
    notifyListeners();

    // Show incoming transfer notification/dialog
    NotificationService.showIncomingTransfer(fileName, deviceName, transferId);
  }

  Future<void> acceptTransfer(String transferId, String savePath) async {
    final transfer = _getTransfer(transferId);
    if (transfer == null) return;

    final socket = _activeConnections[transferId];
    if (socket == null) return;

    // Send acceptance
    final response = {'accepted': true};
    socket.write(jsonEncode(response) + '\n');

    // Update transfer with save path
    _updateTransfer(transferId, 
      filePath: savePath,
      status: TransferStatus.inProgress,
    );

    // Start receiving file
    await _performFileReceive(transferId, savePath, socket);
  }

  Future<void> declineTransfer(String transferId) async {
    final socket = _activeConnections[transferId];
    if (socket != null) {
      final response = {'accepted': false};
      socket.write(jsonEncode(response) + '\n');
      socket.close();
      _activeConnections.remove(transferId);
    }

    _updateTransfer(transferId, status: TransferStatus.cancelled);
  }

  Future<void> _performFileReceive(String transferId, String savePath, Socket socket) async {
    final transfer = _getTransfer(transferId);
    if (transfer == null) return;

    final file = File(savePath);
    final sink = file.openWrite();
    int bytesReceived = 0;
    final startTime = DateTime.now();

    try {
      await for (final chunk in socket) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        
        final progress = bytesReceived / transfer.fileSize;
        final elapsed = DateTime.now().difference(startTime);
        final speed = bytesReceived / elapsed.inSeconds;
        
        _updateTransfer(transferId,
          progress: progress,
          bytesTransferred: bytesReceived,
          speed: speed,
        );

        if (bytesReceived >= transfer.fileSize) {
          break;
        }
      }

      await sink.flush();
      await sink.close();
      socket.close();

      _updateTransfer(transferId, 
        status: TransferStatus.completed,
        endTime: DateTime.now(),
      );

      NotificationService.showTransferComplete(transfer.fileName, false);

    } catch (e) {
      debugPrint('File receive error: $e');
      await sink.close();
      _updateTransfer(transferId, 
        status: TransferStatus.failed,
        errorMessage: e.toString(),
        endTime: DateTime.now(),
      );
    }
  }

  void cancelTransfer(String transferId) {
    final socket = _activeConnections[transferId];
    socket?.close();
    _activeConnections.remove(transferId);
    
    final subscription = _transferSubscriptions[transferId];
    subscription?.cancel();
    _transferSubscriptions.remove(transferId);

    _updateTransfer(transferId, 
      status: TransferStatus.cancelled,
      endTime: DateTime.now(),
    );
  }

  void _updateTransfer(String transferId, {
    TransferStatus? status,
    double? progress,
    int? bytesTransferred,
    double? speed,
    DateTime? endTime,
    String? errorMessage,
    String? filePath,
  }) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index >= 0) {
      _transfers[index] = _transfers[index].copyWith(
        status: status,
        progress: progress,
        bytesTransferred: bytesTransferred,
        speed: speed,
        endTime: endTime,
        errorMessage: errorMessage,
        filePath: filePath,
      );
      notifyListeners();
    }
  }

  FileTransfer? _getTransfer(String transferId) {
    try {
      return _transfers.firstWhere((t) => t.id == transferId);
    } catch (e) {
      return null;
    }
  }

  void clearHistory() {
    _transfers.removeWhere((t) => 
      t.status == TransferStatus.completed || 
      t.status == TransferStatus.failed ||
      t.status == TransferStatus.cancelled
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
