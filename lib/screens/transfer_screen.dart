// ignore_for_file: use_build_context_synchronously, prefer_expression_function_bodies

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/device.dart';
import '../models/file_transfer.dart';
import '../providers/transfer_provider.dart';
import '../services/network_service.dart';
import '../services/file_service.dart';
import '../widgets/transfer_progress_card.dart';

class TransferScreen extends StatefulWidget {
  final List<File> files;
  final Device targetDevice;
  final bool isSending;

  const TransferScreen({
    super.key,
    required this.files,
    required this.targetDevice,
    required this.isSending,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final List<FileTransfer> _transfers = [];
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    _initializeTransfers();
    _startTransfer();
  }

  void _initializeTransfers() {
    for (final file in widget.files) {
      final transfer = FileTransfer(
        id: DateTime.now().millisecondsSinceEpoch.toString() + file.hashCode.toString(),
        fileName: file.path.split('/').last,
        filePath: file.path,
        fileSize: file.lengthSync(),
        deviceId: widget.targetDevice.id,
        deviceName: widget.targetDevice.name,
        direction: widget.isSending ? TransferDirection.sending : TransferDirection.receiving,
        timestamp: DateTime.now(),
      );
      
      _transfers.add(transfer);
      context.read<TransferProvider>().addTransfer(transfer);
    }
  }

  Future<void> _startTransfer() async {
    setState(() => _isTransferring = true);

    try {
      final networkService = context.read<NetworkService>();
      final transferProvider = context.read<TransferProvider>();

      for (final transfer in _transfers) {
        final file = File(transfer.filePath);
        
        transferProvider.updateTransfer(
          transfer.id,
          status: TransferStatus.inProgress,
        );

        try {
          // Use the network service to send each file. It handles the connection internally.
          await networkService.sendFile(widget.targetDevice, file, transfer.id, (bytesSent, totalBytes) {
            if (mounted) {
              transferProvider.updateTransfer(
                transfer.id,
                bytesTransferred: bytesSent,
              );
            }
          });
          // This screen is simple, so we mark as complete on successful send.
          // The main chat screen waits for receiver confirmation.
          if (mounted) {
            transferProvider.updateTransfer(transfer.id, status: TransferStatus.completed);
          }
        } catch (e) {
          if (mounted) {
            transferProvider.updateTransfer(
              transfer.id,
              status: TransferStatus.failed,
              errorMessage: e.toString(),
            );
          }
        }
      }
    } catch (e) {
      _showError('Transfer failed: $e');
    } finally {
      setState(() => _isTransferring = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSending ? 'Sending Files' : 'Receiving Files'),
        leading: _isTransferring 
            ? null 
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(widget.targetDevice.name[0].toUpperCase()),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.targetDevice.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${widget.targetDevice.platform} • ${widget.targetDevice.ipAddress}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isTransferring)
                  const CircularProgressIndicator(),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transfers.length,
              itemBuilder: (context, index) {
                final transfer = _transfers[index];
                return Consumer<TransferProvider>(
                  builder: (context, provider, child) {
                    final updatedTransfer = provider.getTransfer(transfer.id) ?? transfer;
                    return TransferProgressCard(transfer: updatedTransfer);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
