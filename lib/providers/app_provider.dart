import 'dart:io';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AppProvider extends ChangeNotifier {
  final SettingsService _settingsService;

  String _deviceName = Platform.localHostname;
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  AppProvider(this._settingsService);

  String get deviceName => _deviceName;
  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final savedName = await _settingsService.getDeviceName();
    if (savedName != null && savedName.isNotEmpty) {
      _deviceName = savedName;
    } else {
      // If no name is saved, save the default hostname
      await _settingsService.setDeviceName(_deviceName);
    }
    
    // You can also load theme mode here if you implement it
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> updateDeviceName(String newName) async {
    if (newName.trim().isEmpty) return;
    _deviceName = newName.trim();
    await _settingsService.setDeviceName(_deviceName);
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode newThemeMode) async {
    _themeMode = newThemeMode;
    await _settingsService.setThemeMode(newThemeMode.name);
    notifyListeners();
  }
}