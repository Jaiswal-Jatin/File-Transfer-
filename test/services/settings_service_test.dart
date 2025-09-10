import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_file_share/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsService', () {
    late SettingsService settingsService;

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      settingsService = SettingsService();
      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('should initialize with default values', () {
      expect(settingsService.deviceName, isNotEmpty);
      expect(settingsService.isDarkMode, false);
      expect(settingsService.autoAccept, false);
      expect(settingsService.port, 8080);
      expect(settingsService.isDiscoverable, true);
    });

    test('should update device name', () async {
      const newName = 'Test Device';
      await settingsService.setDeviceName(newName);
      expect(settingsService.deviceName, newName);
    });

    test('should toggle dark mode', () async {
      expect(settingsService.isDarkMode, false);
      await settingsService.setDarkMode(true);
      expect(settingsService.isDarkMode, true);
    });

    test('should update port number', () async {
      const newPort = 9090;
      await settingsService.setPort(newPort);
      expect(settingsService.port, newPort);
    });

    test('should toggle auto accept', () async {
      expect(settingsService.autoAccept, false);
      await settingsService.setAutoAccept(true);
      expect(settingsService.autoAccept, true);
    });

    test('should toggle discoverable status', () async {
      expect(settingsService.isDiscoverable, true);
      await settingsService.setDiscoverable(false);
      expect(settingsService.isDiscoverable, false);
    });

    test('should clear all settings', () async {
      // Set some values
      await settingsService.setDeviceName('Custom Name');
      await settingsService.setDarkMode(true);
      await settingsService.setPort(9999);
      
      // Clear settings
      await settingsService.clearAllSettings();
      
      // Verify defaults are restored
      expect(settingsService.isDarkMode, false);
      expect(settingsService.port, 8080);
      expect(settingsService.isDiscoverable, true);
    });
  });
}
