import 'package:flutter/material.dart';
import '../models/file_transfer.dart';

class TransferProgressCard extends StatelessWidget {
  final FileTransfer transfer;

  const TransferProgressCard({
    super.key,
    required this.transfer,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    transfer.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                _buildStatusIcon(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${transfer.formattedSize} • ${transfer.deviceName}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: transfer.progress,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(transfer.progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12),
                ),
                if (transfer.status == TransferStatus.inProgress)
                  Text(
                    transfer.formattedSpeed,
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            if (transfer.estimatedTimeRemaining != null && 
                transfer.status == TransferStatus.inProgress)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'ETA: ${_formatDuration(transfer.estimatedTimeRemaining!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            if (transfer.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  transfer.errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (transfer.status) {
      case TransferStatus.pending:
        return const Icon(Icons.schedule, color: Colors.orange, size: 20);
      case TransferStatus.inProgress:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case TransferStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case TransferStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case TransferStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.grey, size: 20);
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}
