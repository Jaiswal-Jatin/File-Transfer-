// ignore_for_file: prefer_expression_function_bodies, cascade_invocations

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart';
import '../models/device.dart';
import '../models/chat_message.dart';
import '../models/file_transfer.dart';
import '../providers/chat_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/network_service.dart';
import '../widgets/chat_bubble.dart';

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
          final transfer = transferProvider.getTransfer(transferId);
          if (transfer == null) break;

          // This event can be local (for receiver) or from network (for sender)
          if (fromDeviceId == widget.device.id && transfer.direction == TransferDirection.sending) {
            // I am the SENDER, and this is a confirmation from the receiver.
            transferProvider.updateTransfer(
              transferId,
              status: TransferStatus.completed,
            );
          } else if (fromDeviceId == null && transfer.direction == TransferDirection.receiving) {
            // I am the RECEIVER, and this is a local event from my NetworkService.
            final filePath = event['filePath'] as String;
            transferProvider.updateTransfer(
              transferId,
              status: TransferStatus.completed,
              filePath: filePath,
            );
            // Send confirmation back to the sender.
            context.read<NetworkService>().sendMessage(widget.device, {
              'type': NetworkService.msgTypeFileComplete,
              'transferId': transferId,
            });
          }
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

  Future<void> _onAttemptPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must choose an action
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect'),
        content: Text('Are you sure you want to disconnect from ${widget.device.name}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false); // Stay on screen
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true); // Allow pop
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (shouldPop ?? false && mounted) {
      Navigator.of(context).pop();
    }
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

  // This method explains where to implement the folder creation logic.
  void _handleFileRequest(Map<String, dynamic> data) {
    // BUG FIX: Instead of modifying a final field, we create a new FileTransfer
    // object with the correct deviceId from the sender.
    final transfer = FileTransfer(
      id: data['id'],
      fileName: data['fileName'],
      filePath: data['filePath'] ?? data['fileName'],
      fileSize: data['fileSize'],
      // Associate the transfer with the sender's device, not the receiver's.
      deviceId: widget.device.id,
      deviceName: widget.device.name,
      // Set direction for the receiver.
      direction: TransferDirection.receiving,
      // Restore other fields from the payload.
      status: TransferStatus.values[data['status']],
      bytesTransferred: data['bytesTransferred'] ?? 0,
      speed: data['speed']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(data['timestamp']),
      endTime: data['endTime'] != null ? DateTime.parse(data['endTime']) : null,
      errorMessage: data['errorMessage'],
    );

    // The initial file path is just the name; it will be updated on completion.
    // The actual file saving and path determination happens in your NetworkService.
    // To save files into a "p2p file sher" folder, you should modify the part
    // of your NetworkService that handles receiving file data.
    // It should look something like this (conceptual code):
    // 1. Get a suitable directory: `final dir = await getApplicationDocumentsDirectory();` (from path_provider)
    // 2. Create your custom folder: `final saveDir = Directory('${dir.path}/p2p file sher'); await saveDir.create(recursive: true);`
    // 3. Create the final file path: `final finalPath = '${saveDir.path}/${transfer.fileName}';`
    // 4. Save the incoming file stream to `finalPath`.
    // 5. Send this `finalPath` back in the 'msgTypeFileComplete' message.

    final transferProvider = context.read<TransferProvider>();
    transferProvider.addTransfer(transfer);

    // Auto-accept the file
    final networkService = context.read<NetworkService>();
    networkService.sendMessage(widget.device, {
      'type': NetworkService.msgTypeFileResponse,
      'transferId': transfer.id,
      'accepted': true,
    });
    transferProvider.updateTransfer(transfer.id, status: TransferStatus.inProgress);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Receiving "${transfer.fileName}" from ${widget.device.name}')),
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
      transferProvider.updateTransfer(transferId,
          status: TransferStatus.inProgress);
      _initiateFileSend(transfer);
    } else {
      transferProvider.updateTransfer(transferId,
          status: TransferStatus.cancelled);
    }
  }

  void _initiateFileSend(FileTransfer transfer) {
    final networkService = context.read<NetworkService>();
    final file = File(transfer.filePath);
    final transferProvider = context.read<TransferProvider>();

    // We don't want to block the UI, so we run this in the background.
    networkService
        .sendFile(widget.device, file, transfer.id, (bytesSent, totalBytes) {
      // This is the progress callback for the sender's UI
      if (mounted) {
        transferProvider.updateTransfer(
          transfer.id,
          bytesTransferred: bytesSent,
        );
        if (bytesSent == totalBytes) {
          // SENDER-SIDE COMPLETION:
          // Do not mark as completed here. The sender should wait for a
          // 'msgTypeFileComplete' confirmation from the receiver.
          // The transfer will remain 'inProgress' until then.
        }
      }
    }).catchError((e) {
      if (mounted) {
        transferProvider.updateTransfer(
          transfer.id,
          status: TransferStatus.failed,
          errorMessage: e.toString(),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Scroll to bottom when keyboard appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (MediaQuery.of(context).viewInsets.bottom > 0) {
        _scrollToBottom();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        _onAttemptPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                child: Text(widget.device.name[0].toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.device.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Online',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Disconnect',
              onPressed: _onAttemptPop,
            ),
          ],
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
                        return _buildTransferItem(item);
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, -1),
              blurRadius: 4,
              color: Theme.of(context).shadowColor.withOpacity(0.05),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickFiles,
              color: Colors.grey[600],
              tooltip: 'Attach File',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[850],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
                onSubmitted: (text) => text.trim().isNotEmpty ? _sendMessage() : null,
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) => IconButton(
                icon: const Icon(Icons.send),
                onPressed: value.text.trim().isEmpty ? null : _sendMessage,
                color: Theme.of(context).primaryColor,
                tooltip: 'Send Message',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // This is the main dispatcher widget for transfers.
  // It decides whether to show a large image preview or a generic file card.
  Widget _buildTransferItem(FileTransfer transfer) {
    final fileName = transfer.fileName.toLowerCase();
    final isImage = fileName.endsWith('.png') || fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.gif');

    // We can show a preview if the file path exists (i.e., it's a sent file or a completed received file)
    final canShowImagePreview = isImage && transfer.filePath.isNotEmpty && File(transfer.filePath).existsSync();

    if (canShowImagePreview) {
      return _buildImageTransferItem(transfer);
    } else {
      // For non-images or images being received (where we don't have the file yet).
      return _buildFileCardItem(transfer);
    }
  }

  /// Builds a visually rich preview for image transfers.
  Widget _buildImageTransferItem(FileTransfer transfer) {
    final file = File(transfer.filePath);
    final isSending = transfer.direction == TransferDirection.sending;

    return Align(
      alignment: isSending ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
          maxHeight: 300,
        ),
        child: InkWell(
          onTap: () => _handleTransferTap(transfer),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    );
                  },
                ),
                // Status badge at the bottom
                Positioned(
                  bottom: 5,
                  right: 8,
                  child: _buildStatusBadge(transfer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a new, modern card UI for non-image files.
  Widget _buildFileCardItem(FileTransfer transfer) {
    final isSending = transfer.direction == TransferDirection.sending;

    IconData iconData;
    final fileName = transfer.fileName.toLowerCase();
    if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) iconData = Icons.video_file_rounded;
    else if (fileName.endsWith('.pdf')) iconData = Icons.picture_as_pdf_rounded;
    else if (fileName.endsWith('.apk')) iconData = Icons.android_rounded;
    else if (fileName.endsWith('.zip') || fileName.endsWith('.rar')) iconData = Icons.folder_zip_rounded;
    else if (fileName.endsWith('.mp3') || fileName.endsWith('.wav')) iconData = Icons.audio_file_rounded;
    else iconData = Icons.insert_drive_file_rounded;

    Widget statusWidget;
    switch (transfer.status) {
      case TransferStatus.inProgress:
        statusWidget = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: transfer.progress > 0 ? transfer.progress : null),
            const SizedBox(height: 4),
            Text(
              '${(transfer.bytesTransferred / (1024 * 1024)).toStringAsFixed(2)} MB of ${transfer.formattedSize}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        );
        break;
      case TransferStatus.completed:
        statusWidget = Row(children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 18),
          const SizedBox(width: 6),
          Text(
            isSending ? 'Sent' : 'Received',
            style: TextStyle(fontSize: 14, color: Colors.green[700], fontWeight: FontWeight.w500),
          ),
        ]);
        break;
      case TransferStatus.failed:
        statusWidget = Row(children: [
          const Icon(Icons.error, color: Colors.red, size: 18),
          const SizedBox(width: 6),
          const Text('Failed', style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.w500)),
        ]);
        break;
      case TransferStatus.pending:
        statusWidget = Row(children: [
          const Icon(Icons.hourglass_empty, color: Colors.orange, size: 18),
          const SizedBox(width: 6),
          const Text('Waiting...', style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.w500)),
        ]);
        break;
      default:
        statusWidget = const SizedBox.shrink();
    }

    return Align(
      alignment: isSending ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        width: MediaQuery.of(context).size.width * 0.75,
        child: InkWell(
          onTap: () => _handleTransferTap(transfer),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 1.5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                        child: Icon(iconData, color: Theme.of(context).primaryColor, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transfer.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transfer.formattedSize,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  statusWidget,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A small badge showing status, primarily for image previews.
  Widget _buildStatusBadge(FileTransfer transfer) {
    final isSending = transfer.direction == TransferDirection.sending;
    String statusText;
    IconData? statusIcon;

    switch (transfer.status) {
      case TransferStatus.completed:
        statusText = isSending ? 'Sent' : 'Received';
        statusIcon = Icons.check_circle;
        break;
      case TransferStatus.inProgress:
        statusText = '${(transfer.progress * 100).toStringAsFixed(0)}%';
        statusIcon = null; // Progress is shown by the main indicator
        break;
      case TransferStatus.pending:
        statusText = 'Waiting';
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          if (statusIcon != null) ...[
            const SizedBox(width: 4),
            Icon(statusIcon, color: Colors.white, size: 14),
          ],
        ],
      ),
    );
  }

  /*
    final fileName = transfer.fileName.toLowerCase();
    final isImage = fileName.endsWith('.png') || fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.gif');

    if (isImage && (transfer.direction == TransferDirection.sending || transfer.status == TransferStatus.completed)) {
      final file = File(transfer.filePath);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(
          file,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.image, size: 30);
          },
        ),
      );
    }

    IconData iconData;
    if (isImage) iconData = Icons.image_outlined;
    else if (fileName.endsWith('.mp4') || fileName.endsWith('.mov')) iconData = Icons.video_file_outlined;
    else if (fileName.endsWith('.pdf')) iconData = Icons.picture_as_pdf_outlined;
    else if (fileName.endsWith('.apk')) iconData = Icons.android;
    else iconData = Icons.insert_drive_file_outlined;

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Icon(iconData, color: Theme.of(context).primaryColor),
    );
  */

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
    
    final networkService = context.read<NetworkService>();
    networkService.sendMessage(widget.device, {
      'type': NetworkService.msgTypeChat,
      'id': message.id,
      'message': message.message,
      'deviceInfo': {
        'deviceId': networkService.deviceId,
        'deviceName': networkService.deviceName,
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

  Future<void> _handleTransferTap(FileTransfer transfer) async {
    if (transfer.status == TransferStatus.completed) {
      // Open the file if transfer is complete
      try {
        final result = await OpenFilex.open(transfer.filePath);
        if (result.type != ResultType.done) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    } else if (transfer.status == TransferStatus.failed && transfer.direction == TransferDirection.sending) {
      // Ask to retry a failed send transfer
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Retry Transfer?'),
          content: Text('Do you want to try sending "${transfer.fileName}" again?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                final transferProvider = context.read<TransferProvider>();
                transferProvider.updateTransfer(transfer.id, status: TransferStatus.inProgress, bytesTransferred: 0, errorMessage: null);
                _initiateFileSend(transfer);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _sendData(Map<String, dynamic> data) async {
    // This method is now a wrapper around the centralized NetworkService.
    // The NetworkService should manage a persistent socket connection.
    final networkService = context.read<NetworkService>();
    try {
      await networkService.sendMessage(widget.device, data);
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
