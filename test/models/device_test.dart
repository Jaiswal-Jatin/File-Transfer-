import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_file_share/models/device.dart';


void main() {
  group('Device', () {
    late Device device;
    late DateTime testTime;

    setUp(() {
      testTime = DateTime.now();
      device = Device(
        id: 'test-id',
        name: 'Test Device',
        ipAddress: '192.168.1.100',
        port: 8080,
        isConnected: true,
        lastSeen: testTime,
      );
    });

    test('should create device with correct properties', () {
      expect(device.id, 'test-id');
      expect(device.name, 'Test Device');
      expect(device.ipAddress, '192.168.1.100');
      expect(device.port, 8080);
      expect(device.isConnected, true);
      expect(device.lastSeen, testTime);
    });

    test('should create copy with updated properties', () {
      final updatedDevice = device.copyWith(
        name: 'Updated Device',
        isConnected: false,
      );

      expect(updatedDevice.id, device.id);
      expect(updatedDevice.name, 'Updated Device');
      expect(updatedDevice.ipAddress, device.ipAddress);
      expect(updatedDevice.port, device.port);
      expect(updatedDevice.isConnected, false);
      expect(updatedDevice.lastSeen, device.lastSeen);
    });

    test('should serialize to and from JSON', () {
      final json = device.toJson();
      final deviceFromJson = Device.fromJson(json);

      expect(deviceFromJson.id, device.id);
      expect(deviceFromJson.name, device.name);
      expect(deviceFromJson.ipAddress, device.ipAddress);
      expect(deviceFromJson.port, device.port);
      expect(deviceFromJson.isConnected, device.isConnected);
      expect(deviceFromJson.lastSeen, device.lastSeen);
    });

    test('should handle default values', () {
      final simpleDevice = Device(
        id: 'simple',
        name: 'Simple Device',
        ipAddress: '192.168.1.1',
        port: 8080,
        lastSeen: testTime,
      );

      expect(simpleDevice.isConnected, false);
    });
  });
}
