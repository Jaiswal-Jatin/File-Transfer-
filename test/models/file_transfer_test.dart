import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_file_share/models/device.dart';
import 'package:p2p_file_share/models/file_transfer.dart';


void main() {
  group('FileTransfer', () {
    late Device testDevice;
    late FileTransfer transfer;
    late DateTime startTime;

    setUp(() {
      startTime = DateTime.now();
      testDevice = Device(
        id: 'test-device',
        name: 'Test Device',
        ipAddress: '192.168.1.100',
        port: 8080,
        lastSeen: startTime,
      );

      transfer = FileTransfer(
        id: 'test-transfer',
        fileName: 'test.jpg',
        filePath: '/path/to/test.jpg',
        fileSize: 1024 * 1024, // 1MB
        device: testDevice,
        direction: TransferDirection.sending,
        status: TransferStatus.inProgress,
        progress: 0.5,
        bytesTransferred: 512 * 1024, // 512KB
        speed: 1024 * 100, // 100KB/s
        startTime: startTime,
      );
    });

    test('should create transfer with correct properties', () {
      expect(transfer.id, 'test-transfer');
      expect(transfer.fileName, 'test.jpg');
      expect(transfer.fileSize, 1024 * 1024);
      expect(transfer.direction, TransferDirection.sending);
      expect(transfer.status, TransferStatus.inProgress);
      expect(transfer.progress, 0.5);
      expect(transfer.bytesTransferred, 512 * 1024);
      expect(transfer.speed, 1024 * 100);
    });

    test('should calculate estimated time remaining', () {
      final eta = transfer.estimatedTimeRemaining;
      expect(eta, isNotNull);
      expect(eta!.inSeconds, greaterThan(0));
    });

    test('should format speed correctly', () {
      expect(transfer.formattedSpeed, '100.0 KB/s');
      
      final fastTransfer = transfer.copyWith(speed: 1024 * 1024 * 2.5); // 2.5 MB/s
      expect(fastTransfer.formattedSpeed, '2.5 MB/s');
      
      final slowTransfer = transfer.copyWith(speed: 500); // 500 B/s
      expect(slowTransfer.formattedSpeed, '500 B/s');
    });

    test('should format file size correctly', () {
      expect(transfer.formattedSize, '1.0 MB');
      
      final smallTransfer = transfer.copyWith(fileSize: 1500); // 1.5 KB
      expect(smallTransfer.formattedSize, '1.5 KB');
      
      final largeTransfer = transfer.copyWith(fileSize: 1024 * 1024 * 1024 * 2); // 2 GB
      expect(largeTransfer.formattedSize, '2.0 GB');
    });

    test('should create copy with updated properties', () {
      final updatedTransfer = transfer.copyWith(
        status: TransferStatus.completed,
        progress: 1.0,
        endTime: DateTime.now(),
      );

      expect(updatedTransfer.status, TransferStatus.completed);
      expect(updatedTransfer.progress, 1.0);
      expect(updatedTransfer.endTime, isNotNull);
      expect(updatedTransfer.id, transfer.id); // Unchanged properties
    });

    test('should handle completed transfer ETA', () {
      final completedTransfer = transfer.copyWith(
        progress: 1.0,
        status: TransferStatus.completed,
      );
      
      expect(completedTransfer.estimatedTimeRemaining, isNull);
    });

    test('should handle zero speed ETA', () {
      final stoppedTransfer = transfer.copyWith(speed: 0);
      expect(stoppedTransfer.estimatedTimeRemaining, isNull);
    });
  });
}
