// ignore_for_file: prefer_expression_function_bodies

import 'device.dart';

enum TransferStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
  paused,
}

enum TransferDirection {
  sending,
  receiving,
}

class FileTransfer {
  final String id;
  final String fileName;
  final String filePath;
  final int fileSize;
  final Device device;
  final TransferDirection direction;
  final TransferStatus status;
  final double progress;
  final int bytesTransferred;
  final double speed; // bytes per second
  final DateTime startTime;
  final DateTime? endTime;
  final String? errorMessage;

  const FileTransfer({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.device,
    required this.direction,
    required this.status,
    this.progress = 0.0,
    this.bytesTransferred = 0,
    this.speed = 0.0,
    required this.startTime,
    this.endTime,
    this.errorMessage,
  });

  FileTransfer copyWith({
    String? id,
    String? fileName,
    String? filePath,
    int? fileSize,
    Device? device,
    TransferDirection? direction,
    TransferStatus? status,
    double? progress,
    int? bytesTransferred,
    double? speed,
    DateTime? startTime,
    DateTime? endTime,
    String? errorMessage,
  }) {
    return FileTransfer(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      device: device ?? this.device,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      speed: speed ?? this.speed,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Duration? get estimatedTimeRemaining {
    if (speed <= 0 || progress >= 1.0) return null;
    final remainingBytes = fileSize - bytesTransferred;
    return Duration(seconds: (remainingBytes / speed).round());
  }

  String get formattedSpeed {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
