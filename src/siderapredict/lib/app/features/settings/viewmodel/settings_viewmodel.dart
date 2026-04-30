import 'package:flutter/material.dart';
import 'package:siderapredict/app/core/services/settings_service.dart';
import 'package:siderapredict/app/core/theme/theme.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsService _settingsService;

  SettingsViewModel({required SettingsService settingsService})
      : _settingsService = settingsService;

  bool get isDarkMode => _settingsService.isDarkMode;
  bool get isHighContrast => _settingsService.isHighContrast;

  ThemeData get currentTheme {
    if (isHighContrast) {
      return buildHighContrastTheme(false); // High contrast is now exclusive
    }
    return isDarkMode ? buildDarkTheme() : buildLightTheme();
  }

  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggleDarkMode(bool value) async {
    if (value) {
      // If turning on Dark Mode, turn off High Contrast
      await _settingsService.setHighContrast(false);
    }
    await _settingsService.setDarkMode(value);
    notifyListeners();
  }

  Future<void> toggleHighContrast(bool value) async {
    if (value) {
      // If turning on High Contrast, turn off Dark Mode
      await _settingsService.setDarkMode(false);
    }
    await _settingsService.setHighContrast(value);
    notifyListeners();
  }
}
