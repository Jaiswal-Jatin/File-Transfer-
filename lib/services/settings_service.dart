import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _deviceNameKey = 'device_name';
  static const String _isDarkModeKey = 'is_dark_mode';
  static const String _autoAcceptKey = 'auto_accept';
  static const String _defaultSaveFolderKey = 'default_save_folder';
  static const String _portKey = 'port';
  static const String _isDiscoverableKey = 'is_discoverable';
  static const String _deviceIdKey = 'device_id'; // New: Device ID key

  SharedPreferences? _prefs;
  
  String _deviceName = '';
  bool _isDarkMode = false;
  bool _autoAccept = false;
  String _defaultSaveFolder = '';
  int _port = 4040; // Changed default port from 8080 to 4040
  bool _isDiscoverable = true;
  String? _deviceId; // New: Device ID

  // Getters
  String get deviceName => _deviceName;
  bool get isDarkMode => _isDarkMode;
  bool get autoAccept => _autoAccept;
  String get defaultSaveFolder => _defaultSaveFolder;
  int get port => _port;
  bool get isDiscoverable => _isDiscoverable;
  String? get deviceId => _deviceId; // New: Device ID getter

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    _deviceName = _prefs?.getString(_deviceNameKey) ?? _getDefaultDeviceName();
    _isDarkMode = _prefs?.getBool(_isDarkModeKey) ?? false;
    _autoAccept = _prefs?.getBool(_autoAcceptKey) ?? false;
    _defaultSaveFolder = _prefs?.getString(_defaultSaveFolderKey) ?? '';
    _port = _prefs?.getInt(_portKey) ?? 4040; // Changed default port to 4040
    _isDiscoverable = _prefs?.getBool(_isDiscoverableKey) ?? true;
    _deviceId = _prefs?.getString(_deviceIdKey); // New: Load device ID
    
    notifyListeners();
  }

  String _getDefaultDeviceName() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Android Device';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iPhone';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'Mac';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'Windows PC';
    }
    return 'Unknown Device';
  }

  Future<void> setDeviceName(String name) async {
    _deviceName = name;
    await _prefs?.setString(_deviceNameKey, name);
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _prefs?.setBool(_isDarkModeKey, isDark);
    notifyListeners();
  }

  Future<void> setAutoAccept(bool autoAccept) async {
    _autoAccept = autoAccept;
    await _prefs?.setBool(_autoAcceptKey, autoAccept);
    notifyListeners();
  }

  Future<void> setDefaultSaveFolder(String folder) async {
    _defaultSaveFolder = folder;
    await _prefs?.setString(_defaultSaveFolderKey, folder);
    notifyListeners();
  }

  Future<void> setPort(int port) async {
    _port = port;
    await _prefs?.setInt(_portKey, port);
    notifyListeners();
  }

  Future<void> setDiscoverable(bool discoverable) async {
    _isDiscoverable = discoverable;
    await _prefs?.setBool(_isDiscoverableKey, discoverable);
    notifyListeners();
  }

  // New: Set Device ID
  Future<void> setDeviceId(String id) async {
    _deviceId = id;
    await _prefs?.setString(_deviceIdKey, id);
    notifyListeners();
  }

  Future<void> clearAllSettings() async {
    await _prefs?.clear();
    await _loadSettings();
  }
}
