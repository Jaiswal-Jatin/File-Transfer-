import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/transfer_service.dart';
import '../models/file_transfer.dart';
import '../widgets/transfer_item.dart';
import '../widgets/receive_dialog.dart';

class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Start listening for transfers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transferService = context.read<TransferService>();
      transferService.startListening(8080);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Transfers',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_history':
                  _showClearHistoryDialog();
                  break;
                case 'pause_all':
                  _pauseAllTransfers();
                  break;
                case 'cancel_all':
                  _cancelAllTransfers();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_history',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 12),
                    Text('Clear History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pause_all',
                child: Row(
                  children: [
                    Icon(Icons.pause),
                    SizedBox(width: 12),
                    Text('Pause All'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel_all',
                child: Row(
                  children: [
                    Icon(Icons.cancel),
                    SizedBox(width: 12),
                    Text('Cancel All'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Consumer<TransferService>(
              builder: (context, transferService, child) {
                final ongoingCount = transferService.ongoingTransfers.length;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Ongoing'),
                      if (ongoingCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$ongoingCount',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Consumer<TransferService>(
              builder: (context, transferService, child) {
                final historyCount = transferService.completedTransfers.length;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('History'),
                      if (historyCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$historyCount',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOngoingTransfers(),
          _buildTransferHistory(),
        ],
      ),
    );
  }

  Widget _buildOngoingTransfers() {
    return Consumer<TransferService>(
      builder: (context, transferService, child) {
        final ongoingTransfers = transferService.ongoingTransfers;

        if (ongoingTransfers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ongoing transfers',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'File transfers will appear here when active',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ongoingTransfers.length,
          itemBuilder: (context, index) {
            final transfer = ongoingTransfers[index];
            return TransferItem(
              transfer: transfer,
              onCancel: () => transferService.cancelTransfer(transfer.id),
              onRetry: transfer.status == TransferStatus.failed
                  ? () => _retryTransfer(transfer)
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildTransferHistory() {
    return Consumer<TransferService>(
      builder: (context, transferService, child) {
        final completedTransfers = transferService.completedTransfers;

        if (completedTransfers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No transfer history',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Completed transfers will appear here',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: completedTransfers.length,
          itemBuilder: (context, index) {
            final transfer = completedTransfers[index];
            return TransferItem(
              transfer: transfer,
              onRetry: transfer.status == TransferStatus.failed
                  ? () => _retryTransfer(transfer)
                  : null,
              onOpenFile: transfer.status == TransferStatus.completed &&
                      transfer.direction == TransferDirection.receiving
                  ? () => _openFile(transfer)
                  : null,
            );
          },
        );
      },
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'This will remove all completed and failed transfers from the history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TransferService>().clearHistory();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transfer history cleared'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _pauseAllTransfers() {
    // Implementation for pausing all transfers
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pause functionality not yet implemented'),
      ),
    );
  }

  void _cancelAllTransfers() {
    final transferService = context.read<TransferService>();
    final ongoingTransfers = transferService.ongoingTransfers;
    
    if (ongoingTransfers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ongoing transfers to cancel'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel All Transfers'),
        content: Text(
          'This will cancel ${ongoingTransfers.length} ongoing transfer${ongoingTransfers.length == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Transfers'),
          ),
          ElevatedButton(
            onPressed: () {
              for (final transfer in ongoingTransfers) {
                transferService.cancelTransfer(transfer.id);
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All transfers cancelled'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel All'),
          ),
        ],
      ),
    );
  }

  void _retryTransfer(FileTransfer transfer) {
    // Implementation for retrying failed transfers
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retry functionality not yet implemented'),
      ),
    );
  }

  void _openFile(FileTransfer transfer) {
    // Implementation for opening received files
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening ${transfer.fileName}...'),
      ),
    );
  }
}
