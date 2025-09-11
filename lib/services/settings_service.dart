import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _deviceNameKey = 'device_name';
  static const String _themeModeKey = 'theme_mode';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<String?> getDeviceName() async {
    final prefs = await _prefs;
    return prefs.getString(_deviceNameKey);
  }

  Future<void> setDeviceName(String name) async {
    final prefs = await _prefs;
    await prefs.setString(_deviceNameKey, name);
  }

  Future<void> setThemeMode(String themeMode) async {
    final prefs = await _prefs;
    await prefs.setString(_themeModeKey, themeMode);
  }
}