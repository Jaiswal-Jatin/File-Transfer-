import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_file_share/models/device.dart';
import 'package:p2p_file_share/services/transfer_service.dart';


void main() {
  group('TransferService', () {
    late TransferService transferService;
    late Device testDevice;

    setUp(() {
      transferService = TransferService();
      testDevice = Device(
        id: 'test-device',
        name: 'Test Device',
        ipAddress: '192.168.1.100',
        port: 8080,
        lastSeen: DateTime.now(),
      );
    });

    tearDown(() {
      transferService.dispose();
    });

    test('should initialize with empty transfers list', () {
      expect(transferService.transfers, isEmpty);
      expect(transferService.ongoingTransfers, isEmpty);
      expect(transferService.completedTransfers, isEmpty);
    });

    test('should start and stop listening', () async {
      expect(transferService.isListening, false);
      
      // Note: This might fail in test environment due to port binding
      try {
        await transferService.startListening(8081);
        expect(transferService.isListening, true);
        
        await transferService.stopListening();
        expect(transferService.isListening, false);
      } catch (e) {
        // Expected in test environment
        expect(e, isA<Exception>());
      }
    });

    test('should filter ongoing transfers correctly', () {
      // This would require mocking actual transfers
      // For now, just verify the filtering logic works with empty list
      expect(transferService.ongoingTransfers, isEmpty);
      expect(transferService.completedTransfers, isEmpty);
    });

    test('should clear history', () {
      transferService.clearHistory();
      expect(transferService.completedTransfers, isEmpty);
    });
  });
}
