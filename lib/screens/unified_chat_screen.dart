// ignore_for_file: prefer_expression_function_bodies

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/device.dart';
import '../models/message.dart';
import '../services/messaging_service.dart';
import '../services/transfer_service.dart';
import '../services/discovery_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class UnifiedChatScreen extends StatefulWidget {
  final Device device;
  final MessagingService messagingService;

  const UnifiedChatScreen({
    super.key, 
    required this.device,
    required this.messagingService,
  });

  @override
  State<UnifiedChatScreen> createState() => _UnifiedChatScreenState();
}

class _UnifiedChatScreenState extends State<UnifiedChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                widget.device.name.isNotEmpty ? widget.device.name[0].toUpperCase() : 'D',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.name.isNotEmpty ? widget.device.name : 'Unknown Device',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Connected • ${widget.device.ipAddress}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end),
            onPressed: () => _disconnectAndGoBack(),
            tooltip: 'Disconnect',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showDeviceInfo(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: widget.messagingService.getConversationStream(widget.device.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Connected to ${widget.device.name}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send messages, photos, and files securely',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  void _disconnectAndGoBack() async {
    try {
      final discoveryService = Provider.of<DiscoveryService>(context, listen: false);
      await discoveryService.disconnectDevice(widget.device);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from ${widget.device.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from ${widget.device.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Widget _buildMessageBubble(Message message) {
    final isFromMe = message.isFromMe;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isFromMe) const SizedBox(width: 48),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isFromMe
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isFromMe ? 18 : 4),
                  bottomRight: Radius.circular(isFromMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == MessageType.file) 
                    _buildFileMessage(message, isFromMe)
                  else if (message.type == MessageType.image)
                    _buildImageMessage(message, isFromMe)
                  else
                    _buildTextMessage(message, isFromMe),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimeWithAmPm(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isFromMe 
                            ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      if (isFromMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isFromMe) const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTextMessage(Message message, bool isFromMe) {
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 16,
        color: isFromMe
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFileMessage(Message message, bool isFromMe) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromMe
            ? Colors.white.withOpacity(0.1)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: isFromMe ? Colors.black : Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? 'File',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isFromMe ? Colors.black : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (message.fileSize != null)
                  Text(
                    _formatFileSize(message.fileSize!),
                    style: TextStyle(
                      fontSize: 12,
                      color: isFromMe
                          ? Colors.black.withOpacity(0.7)
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage(Message message, bool isFromMe) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: message.filePath != null
            ? Image.file(
                File(message.filePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image),
                  );
                },
              )
            : Container(
                height: 100,
                color: Colors.grey[300],
                child: const Icon(Icons.image),
              ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              onPressed: _showAttachmentOptions,
              icon: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimaryContainer),
              iconSize: 22,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: Icon(Icons.send, color: Theme.of(context).colorScheme.onPrimary),
              iconSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.pink),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        await _sendFile(image.path, MessageType.image);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  void _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        await _sendFile(result.files.single.path!, MessageType.file);
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _sendFile(String filePath, MessageType type) async {
    try {
      final file = File(filePath);
      final fileName = file.path.split('/').last;
      final fileSize = await file.length();
      
      bool success = false;
      
      if (type == MessageType.image) {
        success = await widget.messagingService.sendImageMessage(widget.device, filePath, fileName, fileSize);
      } else {
        success = await widget.messagingService.sendFileMessage(widget.device, filePath, fileName, fileSize);
      }
      
      if (!success && mounted) {
        _showError('Failed to send ${type == MessageType.image ? 'image' : 'file'}');
      }
      
    } catch (e) {
      _showError('Failed to send file: $e');
    }
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    final success = await widget.messagingService.sendTextMessage(widget.device, content);

    if (!success && mounted) {
      _showError('Failed to send message');
    }
  }

  void _showDeviceInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('IP Address', widget.device.ipAddress),
            _buildInfoRow('Port', widget.device.port.toString()),
            _buildInfoRow('Device ID', widget.device.id),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimeWithAmPm(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, y').format(timestamp);
    } else {
      return DateFormat('h:mm a').format(timestamp); // This gives AM/PM format
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
