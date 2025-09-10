import 'package:flutter/material.dart';
import '../models/file_transfer.dart';
import '../services/file_storage_service.dart';

class TransferItem extends StatelessWidget {
  final FileTransfer transfer;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenFile;

  const TransferItem({
    super.key,
    required this.transfer,
    this.onCancel,
    this.onRetry,
    this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // File Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFileIcon(),
                    color: _getStatusColor(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                
                // File Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer.fileName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            transfer.direction == TransferDirection.sending
                                ? Icons.upload
                                : Icons.download,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            transfer.direction == TransferDirection.sending
                                ? 'Sending to ${transfer.device.name}'
                                : 'Receiving from ${transfer.device.name}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _getStatusColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress Section
            if (transfer.status == TransferStatus.inProgress) ...[
              // Progress Bar
              LinearProgressIndicator(
                value: transfer.progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              ),
              const SizedBox(height: 8),
              
              // Progress Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(transfer.progress * 100).toStringAsFixed(0)}% • ${transfer.formattedSpeed}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${FileStorageService.formatFileSize(transfer.bytesTransferred)} / ${transfer.formattedSize}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              
              if (transfer.estimatedTimeRemaining != null) ...[
                const SizedBox(height: 4),
                Text(
                  'ETA: ${_formatDuration(transfer.estimatedTimeRemaining!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else ...[
              // File Size and Time Info
              Row(
                children: [
                  Text(
                    transfer.formattedSize,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _formatTransferTime(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            
            // Error Message
            if (transfer.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transfer.errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action Buttons
            if (onCancel != null || onRetry != null || onOpenFile != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onOpenFile != null) ...[
                    TextButton.icon(
                      onPressed: onOpenFile,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onRetry != null) ...[
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onCancel != null)
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel, size: 16),
                      label: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon() {
    final extension = transfer.fileName.split('.').last.toLowerCase();
    
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

  Color _getStatusColor() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return Colors.orange;
      case TransferStatus.inProgress:
        return Colors.blue;
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.cancelled:
        return Colors.grey;
      case TransferStatus.paused:
        return Colors.orange;
    }
  }

  String _getStatusText() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return 'Pending';
      case TransferStatus.inProgress:
        return 'In Progress';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
      case TransferStatus.paused:
        return 'Paused';
    }
  }

  String _formatTransferTime() {
    final startTime = transfer.startTime;
    final endTime = transfer.endTime ?? DateTime.now();
    final duration = endTime.difference(startTime);
    
    if (transfer.status == TransferStatus.completed) {
      return 'Completed in ${_formatDuration(duration)}';
    } else if (transfer.status == TransferStatus.failed) {
      return 'Failed after ${_formatDuration(duration)}';
    } else {
      return 'Started ${_formatTimeAgo(startTime)}';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
