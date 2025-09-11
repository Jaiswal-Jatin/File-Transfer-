// ignore_for_file: prefer_expression_function_bodies

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/device.dart';
import '../models/chat_message.dart';
import '../models/file_transfer.dart';
import '../providers/chat_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/network_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/transfer_progress_card.dart';

class ChatScreen extends StatefulWidget {
  final Device device;

  const ChatScreen({
    super.key,
    required this.device,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _listenForEvents();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _listenForEvents() {
    final networkService = context.read<NetworkService>();
    _eventSubscription = networkService.eventStream.listen((event) {
      if (!mounted) return;
  
      final type = event['type'];
      final fromDeviceId = (event['deviceInfo'] as Map?)?['deviceId'] as String?;
      final transferProvider = context.read<TransferProvider>();
  
      switch (type) {
        case NetworkService.msgTypeChat:
          if (fromDeviceId == widget.device.id) _handleIncomingMessage(event);
          break;
        case NetworkService.msgTypeFileInfo:
          if (fromDeviceId == widget.device.id) _handleFileRequest(event);
          break;
        case NetworkService.msgTypeFileResponse:
          // This is a response to a request I sent, so no device check needed.
          _handleFileResponse(event);
          break;
        case NetworkService.msgTypeFileProgress:
          final transferId = event['transferId'] as String;
          final bytes = event['bytesTransferred'] as int;
          transferProvider.updateTransfer(transferId, bytesTransferred: bytes);
          break;
        case NetworkService.msgTypeFileComplete:
          final transferId = event['transferId'] as String;
          final filePath = event['filePath'] as String;
          transferProvider.updateTransfer(
            transferId,
            status: TransferStatus.completed,
            filePath: filePath, // Update the final path for the receiver
          );
          break;
        case NetworkService.msgTypeFileError:
          final transferId = event['transferId'] as String;
          final error = event['error'] as String;
          transferProvider.updateTransfer(
            transferId,
            status: TransferStatus.failed,
            errorMessage: error,
          );
          break;
      }
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final message = ChatMessage(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: widget.device.id,
      deviceName: widget.device.name,
      message: data['message'],
      timestamp: DateTime.now(),
      isFromMe: false,
    );
    context.read<ChatProvider>().addMessage(message);
    _scrollToBottom();
  }

  void _handleFileRequest(Map<String, dynamic> data) {
    final transfer = FileTransfer.fromJson(data);
    // Correct the direction for the receiver
    transfer.direction = TransferDirection.receiving;
    // The initial file path is just the name, it will be updated on completion
    transfer.filePath = transfer.fileName;

    context.read<TransferProvider>().addTransfer(transfer);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Incoming File'),
        content: Text('Accept "${transfer.fileName}" (${(transfer.fileSize / 1024 / 1024).toStringAsFixed(2)} MB) from ${widget.device.name}?'),
        actions: [
          TextButton(onPressed: () {
            _sendData({
              'type': NetworkService.msgTypeFileResponse,
              'transferId': transfer.id,
              'accepted': false,
            });
            context.read<TransferProvider>().updateTransfer(transfer.id, status: TransferStatus.cancelled);
            Navigator.of(ctx).pop();
          }, child: const Text('Decline')),
          TextButton(onPressed: () {
             _sendData({
              'type': NetworkService.msgTypeFileResponse,
              'transferId': transfer.id,
              'accepted': true,
            });
            context.read<TransferProvider>().updateTransfer(transfer.id, status: TransferStatus.inProgress);
            Navigator.of(ctx).pop();
          }, child: const Text('Accept')),
        ],
      ),
    );
  }

  void _handleFileResponse(Map<String, dynamic> data) {
    // This is received by the original sender
    final transferId = data['transferId'] as String;
    final accepted = data['accepted'] as bool;
    final transferProvider = context.read<TransferProvider>();
    final transfer = transferProvider.getTransfer(transferId);

    if (transfer == null) return;

    if (accepted) {
      transferProvider.updateTransfer(transferId, status: TransferStatus.inProgress);
      
      // Start the actual file sending process
      final networkService = context.read<NetworkService>();
      final file = File(transfer.filePath);

      // We don't want to block the UI, so we run this in the background.
      networkService.sendFile(widget.device, file, transfer.id, (bytesSent, totalBytes) {
        // This is the progress callback for the sender's UI
        if (mounted) {
          transferProvider.updateTransfer(
            transferId,
            bytesTransferred: bytesSent,
          );
          if (bytesSent == totalBytes) {
             transferProvider.updateTransfer(transferId, status: TransferStatus.completed);
          }
        }
      }).catchError((e) {
        if (mounted) {
          transferProvider.updateTransfer(
            transferId,
            status: TransferStatus.failed,
            errorMessage: e.toString(),
          );
        }
      });
    } else {
      transferProvider.updateTransfer(transferId, status: TransferStatus.cancelled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text(widget.device.name[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Text(
                    'Connected',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer2<ChatProvider, TransferProvider>(
              builder: (context, chatProvider, transferProvider, child) {
                final messages = chatProvider.getConversation(widget.device.id);
                final transfers = transferProvider.getTransfersForDevice(widget.device.id);

                // Combine and sort messages and transfers by time
                final List<dynamic> conversationItems = [...messages, ...transfers];
                conversationItems.sort((a, b) => a.timestamp.compareTo(b.timestamp));
                
                if (conversationItems.isEmpty) {
                  return _buildEmptyChatView();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: conversationItems.length,
                  itemBuilder: (context, index) {
                    final item = conversationItems[index];
                    if (item is ChatMessage) {
                      return ChatBubble(message: item);
                    } else if (item is FileTransfer) {
                      // Use a specific widget for showing file transfers in the chat
                      return TransferProgressCard(transfer: item);
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickFiles,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No messages yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Start a conversation or send a file to ${widget.device.name}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    final transferProvider = context.read<TransferProvider>();

    for (final file in result.files) {
      if (file.path == null) continue;

      final transfer = FileTransfer(
        id: DateTime.now().millisecondsSinceEpoch.toString() + file.hashCode.toString(),
        fileName: file.name,
        filePath: file.path!,
        fileSize: file.size,
        deviceId: widget.device.id,
        deviceName: widget.device.name,
        direction: TransferDirection.sending,
        status: TransferStatus.pending,
        timestamp: DateTime.now(),
      );

      transferProvider.addTransfer(transfer);
      
      // Send file info to the other device
      final fileInfoMessage = transfer.toJson();
      fileInfoMessage['type'] = NetworkService.msgTypeFileInfo;
      _sendData(fileInfoMessage);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deviceId: widget.device.id,
      deviceName: widget.device.name,
      message: text,
      timestamp: DateTime.now(),
      isFromMe: true,
    );

    context.read<ChatProvider>().addMessage(message);
    
    _sendData({
      'type': NetworkService.msgTypeChat,
      'id': message.id,
      'message': message.message,
      'deviceInfo': {
        'deviceId': context.read<NetworkService>().deviceId,
        'deviceName': context.read<NetworkService>().deviceName,
        'ipAddress': context.read<NetworkService>().localIpAddress,
        'port': context.read<NetworkService>().tcpServerPort,
      }
    });
    
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendData(Map<String, dynamic> data) async {
    // Add local device info for the receiver to identify the sender
    if (data['deviceInfo'] == null) {
      final networkService = context.read<NetworkService>();
      data['deviceInfo'] = {
        'deviceId': networkService.deviceId,
        'deviceName': networkService.deviceName,
        'ipAddress': networkService.localIpAddress,
        'port': networkService.tcpServerPort,
        'platform': Platform.operatingSystem,
      };
    }
    // Create a new, temporary socket for each message
    try {
      final socket = await Socket.connect(widget.device.ipAddress, widget.device.port);
      socket.write(jsonEncode(data) + '\n'); // Use newline as a delimiter
      await socket.flush();
      socket.close();
    } catch (e) {
      print('Error sending data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }
}
