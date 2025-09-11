import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/file_transfer.dart';

class TransferHistoryItem extends StatelessWidget {
  final FileTransfer transfer;

  const TransferHistoryItem({
    super.key,
    required this.transfer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor().withOpacity(0.1),
          child: Icon(
            _getDirectionIcon(),
            color: _getStatusColor(),
          ),
        ),
        title: Text(
          transfer.fileName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${transfer.deviceName} • ${transfer.formattedSize}'),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy • HH:mm').format(transfer.startTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 10,
                color: _getStatusColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDirectionIcon() {
    return transfer.direction == TransferDirection.sending
        ? Icons.upload
        : Icons.download;
  }

  IconData _getStatusIcon() {
    switch (transfer.status) {
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  Color _getStatusColor() {
    switch (transfer.status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.cancelled:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText() {
    switch (transfer.status) {
      case TransferStatus.completed:
        return 'Done';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}
