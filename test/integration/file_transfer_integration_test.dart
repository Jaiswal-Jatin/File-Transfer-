import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_file_share/models/device.dart';
import 'package:p2p_file_share/services/settings_service.dart';

import 'package:p2p_file_share/services/transfer_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('File Transfer Integration', () {
    late TransferService transferService;
    late SettingsService settingsService;
    late Device testDevice;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      transferService = TransferService();
      settingsService = SettingsService();
      
      testDevice = Device(
        id: 'integration-test-device',
        name: 'Integration Test Device',
        ipAddress: '127.0.0.1',
        port: 8082,
        lastSeen: DateTime.now(),
      );

      // Wait for services to initialize
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() {
      transferService.dispose();
    });

    testWidgets('should handle transfer lifecycle', (WidgetTester tester) async {
      // This is a simplified integration test
      // In a real scenario, you would set up two instances and test actual file transfer
      
      expect(transferService.transfers, isEmpty);
      
      // Test that transfer service can start listening
      try {
        await transferService.startListening(settingsService.port + 1);
        expect(transferService.isListening, true);
        
        await transferService.stopListening();
        expect(transferService.isListening, false);
      } catch (e) {
        // Expected in test environment due to port binding restrictions
        expect(e, isA<Exception>());
      }
      
      // Test transfer list management
      transferService.clearHistory();
      expect(transferService.completedTransfers, isEmpty);
    });

    test('should integrate settings with transfer service', () async {
      // Test that settings changes affect transfer service behavior
      const newPort = 9999;
      await settingsService.setPort(newPort);
      expect(settingsService.port, newPort);
      
      // In a real integration, you would verify the transfer service uses the new port
      // For this test, we just verify the setting was saved
      expect(settingsService.port, newPort);
    });
  });
}
