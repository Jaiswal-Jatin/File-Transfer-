import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_transfer.dart';
import '../services/transfer_service.dart';
import '../services/file_storage_service.dart';

class ReceiveDialog extends StatefulWidget {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String senderName;

  const ReceiveDialog({
    super.key,
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.senderName,
  });

  @override
  State<ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<ReceiveDialog> {
  String? _selectedPath;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _initializeDefaultPath();
  }

  Future<void> _initializeDefaultPath() async {
    final defaultPath = await FileStorageService.getDefaultDownloadPath();
    final uniquePath = await FileStorageService.generateUniqueFilePath(
      defaultPath,
      widget.fileName,
    );
    setState(() {
      _selectedPath = uniquePath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.file_download,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Incoming File',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.senderName} wants to send:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // File Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIcon(),
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fileName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FileStorageService.formatFileSize(widget.fileSize),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Save Location
          Text(
            'Save to:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPath ?? 'Loading...',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _chooseSaveLocation,
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isAccepting ? null : _declineTransfer,
          child: const Text('Decline'),
        ),
        ElevatedButton(
          onPressed: _isAccepting || _selectedPath == null ? null : _acceptTransfer,
          child: _isAccepting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Accept'),
        ),
      ],
    );
  }

  IconData _getFileIcon() {
    final extension = widget.fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.videocam;
      case 'mp3':
      case 'wav':
        return Icons.audiotrack;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _chooseSaveLocation() async {
    // Implementation for choosing save location
    // This would typically open a directory picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Directory picker not yet implemented'),
      ),
    );
  }

  Future<void> _acceptTransfer() async {
    if (_selectedPath == null) return;

    setState(() {
      _isAccepting = true;
    });

    try {
      await context.read<TransferService>().acceptTransfer(
        widget.transferId,
        _selectedPath!,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepting ${widget.fileName}...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept transfer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  Future<void> _declineTransfer() async {
    try {
      await context.read<TransferService>().declineTransfer(widget.transferId);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer declined'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining transfer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Helper function to show receive dialog
void showReceiveDialog(
  BuildContext context, {
  required String transferId,
  required String fileName,
  required int fileSize,
  required String senderName,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ReceiveDialog(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      senderName: senderName,
    ),
  );
}
