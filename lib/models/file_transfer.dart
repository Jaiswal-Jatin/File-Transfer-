// ignore_for_file: sort_constructors_first

import 'dart:io';

enum TransferStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
}

enum TransferDirection {
  sending,
  receiving,
}

class FileTransfer {
  final String id;
  final String fileName;
  String filePath;
  final int fileSize;
  final String deviceId;
  final String deviceName;
  TransferDirection direction;
  TransferStatus status;
  int bytesTransferred;
  double speed; // bytes per second
  DateTime timestamp;
  DateTime? endTime;
  String? errorMessage;

  FileTransfer({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.deviceId,
    required this.deviceName,
    required this.direction,
    this.status = TransferStatus.pending,
    this.bytesTransferred = 0,
    this.speed = 0.0,
    required this.timestamp,
    this.endTime,
    this.errorMessage,
  });

  double get progress => fileSize > 0 ? bytesTransferred / fileSize : 0.0;

  Duration get elapsedTime => 
      (endTime ?? DateTime.now()).difference(timestamp);

  Duration? get estimatedTimeRemaining {
    if (speed <= 0 || bytesTransferred <= 0) return null;
    final remainingBytes = fileSize - bytesTransferred;
    return Duration(seconds: (remainingBytes / speed).round());
  }

  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(1)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  factory FileTransfer.fromJson(Map<String, dynamic> json) {
    return FileTransfer(
      id: json['id'],
      fileName: json['fileName'],
      filePath: json['filePath'] ?? json['fileName'],
      fileSize: json['fileSize'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      direction: TransferDirection.values[json['direction']],
      status: TransferStatus.values[json['status']],
      bytesTransferred: json['bytesTransferred'] ?? 0,
      speed: json['speed']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      errorMessage: json['errorMessage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'direction': direction.index,
      'status': status.index,
      'bytesTransferred': bytesTransferred,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }
}
