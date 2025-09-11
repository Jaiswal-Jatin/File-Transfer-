import 'package:flutter/material.dart';
import '../models/file_transfer.dart';

class TransferProvider extends ChangeNotifier {
  final List<FileTransfer> _transfers = [];
  final List<FileTransfer> _activeTransfers = [];

  List<FileTransfer> get transfers => List.unmodifiable(_transfers);
  List<FileTransfer> get activeTransfers => List.unmodifiable(_activeTransfers);

  void addTransfer(FileTransfer transfer) {
    _transfers.insert(0, transfer);
    if (transfer.status == TransferStatus.inProgress) {
      _activeTransfers.add(transfer);
    }
    notifyListeners();
  }

  void updateTransfer(String transferId, {
    TransferStatus? status,
    int? bytesTransferred,
    double? speed,
    String? errorMessage,
    String? filePath,
  }) {
    final index = _transfers.indexWhere((t) => t.id == transferId);
    if (index != -1) {
      final transfer = _transfers[index];
      
      if (status != null) {
        transfer.status = status;
      }
      if (bytesTransferred != null) {
        final now = DateTime.now();
        final duration = now.difference(transfer.timestamp).inMilliseconds;
        if (duration > 500 && bytesTransferred > 0) { // Calculate speed only after a short delay
          transfer.speed = (bytesTransferred / (duration / 1000.0));
        }
        transfer.bytesTransferred = bytesTransferred;
      }
      if (errorMessage != null) transfer.errorMessage = errorMessage;
      if (filePath != null) transfer.filePath = filePath;

      if (status == TransferStatus.completed || 
          status == TransferStatus.failed || 
          status == TransferStatus.cancelled) {
        _activeTransfers.removeWhere((t) => t.id == transferId);
      }

      notifyListeners();
    }
  }

  void removeTransfer(String transferId) {
    _transfers.removeWhere((t) => t.id == transferId);
    _activeTransfers.removeWhere((t) => t.id == transferId);
    notifyListeners();
  }

  void clearHistory() {
    _transfers.clear();
    notifyListeners();
  }

  FileTransfer? getTransfer(String transferId) {
    try {
      return _transfers.firstWhere((t) => t.id == transferId);
    } catch (e) {
      return null;
    }
  }

  List<FileTransfer> getTransfersForDevice(String deviceId) {
    return _transfers.where((t) => t.deviceId == deviceId).toList();
  }
}
