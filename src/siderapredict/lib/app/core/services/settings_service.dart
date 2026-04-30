import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _darkModeKey = 'is_dark_mode';
  static const String _highContrastKey = 'is_high_contrast';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  bool get isDarkMode => _prefs.getBool(_darkModeKey) ?? false;
  bool get isHighContrast => _prefs.getBool(_highContrastKey) ?? false;

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_darkModeKey, value);
  }

  Future<void> setHighContrast(bool value) async {
    await _prefs.setBool(_highContrastKey, value);
  }
}
