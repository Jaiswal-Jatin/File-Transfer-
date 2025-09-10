import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/device.dart';
import '../models/message.dart';
import '../models/message_type.dart' hide MessageType;

class MessagingService extends ChangeNotifier {
  final Map<String, List<Message>> _conversations = {};
  final Map<String, Socket> _activeConnections = {};
  final Map<String, StreamController<List<Message>>> _conversationStreams = {};
  ServerSocket? _messageServer;
  static const int _messagingPort = 8080;

  Map<String, List<Message>> get conversations => Map.unmodifiable(_conversations);

  Stream<List<Message>> getConversationStream(String deviceId) {
    if (!_conversationStreams.containsKey(deviceId)) {
      _conversationStreams[deviceId] = StreamController<List<Message>>.broadcast();
    }
    
    // Send initial conversation data
    final initialMessages = getConversation(deviceId);
    _conversationStreams[deviceId]!.add(initialMessages);
    
    return _conversationStreams[deviceId]!.stream;
  }

  Future<void> startMessageServer() async {
    try {
      _messageServer = await ServerSocket.bind(InternetAddress.anyIPv4, _messagingPort);
      _messageServer!.listen((Socket clientSocket) {
        _handleIncomingConnection(clientSocket);
      });
      debugPrint('Message server started on port $_messagingPort');
    } catch (e) {
      debugPrint('Failed to start message server: $e');
    }
  }

  void _handleIncomingConnection(Socket socket) {
    final List<int> buffer = [];
    
    socket.listen(
      (List<int> data) {
        try {
          buffer.addAll(data);
          
          while (buffer.isNotEmpty) {
            try {
              final messageStr = utf8.decode(buffer);
              final messageData = jsonDecode(messageStr);
              
              if (messageData['type'] == 'file_transfer') {
                _handleFileTransfer(messageData, socket);
              } else {
                final message = Message.fromJson(messageData);
                _addMessage(message.senderId, message);
                
                final ack = jsonEncode({'type': 'message_ack', 'messageId': message.id});
                socket.write(ack);
                socket.flush();
              }
              
              buffer.clear();
              break;
            } catch (e) {
              // If JSON is incomplete, wait for more data
              break;
            }
          }
        } catch (e) {
          debugPrint('Error handling incoming message: $e');
        }
      },
      onDone: () => socket.close(),
      onError: (error) => debugPrint('Socket error: $error'),
    );
  }

  Future<void> _handleFileTransfer(Map<String, dynamic> data, Socket socket) async {
    try {
      final fileName = data['fileName'];
      final fileSize = data['fileSize'];
      final fileType = data['fileType']; // 'image' or 'file'
      final senderId = data['senderId'];
      final messageId = data['messageId'];
      
      // Get app documents directory for file storage
      final directory = await getApplicationDocumentsDirectory();
      final receivedFilesDir = Directory(path.join(directory.path, 'received_files'));
      if (!await receivedFilesDir.exists()) {
        await receivedFilesDir.create(recursive: true);
      }
      
      final filePath = path.join(receivedFilesDir.path, fileName);
      final file = File(filePath);
      
      // Receive file data
      final List<int> fileBuffer = [];
      int receivedBytes = 0;
      
      await for (final chunk in socket) {
        fileBuffer.addAll(chunk);
        receivedBytes += chunk.length;
        
        if (receivedBytes >= fileSize) {
          break;
        }
      }
      
      // Save file to local storage
      await file.writeAsBytes(fileBuffer);
      
      // Create message for received file
      final message = Message(
        id: messageId,
        senderId: senderId,
        receiverId: 'me',
        content: fileName,
        timestamp: DateTime.now(),
        isFromMe: false,
        type: fileType == 'image' ? MessageType.image : MessageType.file,
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
      );
      
      _addMessage(senderId, message);
      
      // Send acknowledgment
      final ack = jsonEncode({'type': 'file_ack', 'messageId': messageId});
      socket.write(ack);
      await socket.flush();
      
      debugPrint('File received and saved: $filePath');
    } catch (e) {
      debugPrint('Error handling file transfer: $e');
    }
  }

  Future<bool> sendTextMessage(Device device, String content) async {
    try {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'me',
        receiverId: device.id,
        content: content,
        timestamp: DateTime.now(),
        isFromMe: true,
        type: MessageType.text,
      );

      return await _sendMessageToDevice(device, message);
    } catch (e) {
      debugPrint('Failed to send text message: $e');
      return false;
    }
  }

  Future<bool> sendFileMessage(Device device, String filePath, String fileName, int fileSize) async {
    try {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'me',
        receiverId: device.id,
        content: fileName,
        timestamp: DateTime.now(),
        isFromMe: true,
        type: MessageType.file,
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
      );

      final success = await _sendFileToDevice(device, message, 'file');
      if (success) {
        _addMessage(device.id, message);
      }
      return success;
    } catch (e) {
      debugPrint('Failed to send file message: $e');
      return false;
    }
  }

  Future<bool> sendImageMessage(Device device, String imagePath, String fileName, int fileSize) async {
    try {
      final message = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'me',
        receiverId: device.id,
        content: fileName,
        timestamp: DateTime.now(),
        isFromMe: true,
        type: MessageType.image,
        filePath: imagePath,
        fileName: fileName,
        fileSize: fileSize,
      );

      final success = await _sendFileToDevice(device, message, 'image');
      if (success) {
        _addMessage(device.id, message);
      }
      return success;
    } catch (e) {
      debugPrint('Failed to send image message: $e');
      return false;
    }
  }

  Future<bool> _sendFileToDevice(Device device, Message message, String fileType) async {
    try {
      final socket = await Socket.connect(device.ipAddress, _messagingPort, 
          timeout: const Duration(seconds: 10));
      
      // Send file transfer metadata first
      final metadata = jsonEncode({
        'type': 'file_transfer',
        'messageId': message.id,
        'senderId': message.senderId,
        'fileName': message.fileName,
        'fileSize': message.fileSize,
        'fileType': fileType,
      });
      
      socket.write(metadata);
      await socket.flush();
      
      // Send file data
      final file = File(message.filePath!);
      final fileBytes = await file.readAsBytes();
      
      socket.add(fileBytes);
      await socket.flush();
      
      // Wait for acknowledgment
      final completer = Completer<bool>();
      late StreamSubscription subscription;
      
      subscription = socket.listen((List<int> data) {
        try {
          final response = jsonDecode(utf8.decode(data));
          if (response['type'] == 'file_ack' && response['messageId'] == message.id) {
            completer.complete(true);
            subscription.cancel();
          }
        } catch (e) {
          debugPrint('Error parsing file ack: $e');
        }
      });
      
      final success = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
      
      socket.close();
      return success;
    } catch (e) {
      debugPrint('Failed to send file to device: $e');
      return false;
    }
  }

  Future<bool> _sendMessageToDevice(Device device, Message message) async {
    try {
      final socket = await Socket.connect(device.ipAddress, _messagingPort, 
          timeout: const Duration(seconds: 5));

      final messageJson = jsonEncode(message.toJson());
      socket.write(messageJson);
      await socket.flush();

      final completer = Completer<bool>();
      late StreamSubscription subscription;
      
      subscription = socket.listen((List<int> data) {
        try {
          final response = jsonDecode(utf8.decode(data));
          if (response['type'] == 'message_ack' && response['messageId'] == message.id) {
            completer.complete(true);
            subscription.cancel();
          }
        } catch (e) {
          debugPrint('Error parsing message ack: $e');
        }
      });
      
      final success = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      _addMessage(device.id, message);
      socket.close();
      return success;
    } catch (e) {
      debugPrint('Failed to send message to device: $e');
      return false;
    }
  }

  void _addMessage(String deviceId, Message message) {
    if (!_conversations.containsKey(deviceId)) {
      _conversations[deviceId] = [];
    }
    _conversations[deviceId]!.add(message);
    
    if (_conversationStreams.containsKey(deviceId)) {
      _conversationStreams[deviceId]!.add(_conversations[deviceId]!);
    }
    
    notifyListeners();
  }

  List<Message> getConversation(String deviceId) {
    return _conversations[deviceId] ?? [];
  }

  void closeConnection(String deviceId) {
    _activeConnections[deviceId]?.close();
    _activeConnections.remove(deviceId);
    
    // Close conversation stream when connection is closed
    _conversationStreams[deviceId]?.close();
    _conversationStreams.remove(deviceId);
  }

  @override
  void dispose() {
    _messageServer?.close();
    for (final socket in _activeConnections.values) {
      socket.close();
    }
    _activeConnections.clear();
    
    for (final controller in _conversationStreams.values) {
      controller.close();
    }
    _conversationStreams.clear();
    
    super.dispose();
  }
}
