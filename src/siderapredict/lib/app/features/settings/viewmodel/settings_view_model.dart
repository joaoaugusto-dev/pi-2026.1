import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/services/settings_service.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

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

  void onAboutPressed(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            AppLogo(height: 22, color: Theme.of(context).primaryColor),
            const SizedBox(width: 24),
            Flexible(
              child: Text(
                'Sidera Predict',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inspeção dimensional com OpenCV + IA.'),
            SizedBox(height: 12),
            Text(
              'Versão 1.0.0',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => onCloseDialogPressed(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  VoidCallback aboutAction(BuildContext context) {
    return () => onAboutPressed(context);
  }

  void onCloseDialogPressed(BuildContext context) {
    Navigator.pop(context);
  }

  Future<void> onLogoutPressed(BuildContext context) async {
    final authViewModel = context.read<AuthViewModel>();
    await authViewModel.logout();
    if (!context.mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  VoidCallback logoutAction(BuildContext context) {
    return () => onLogoutPressed(context);
  }
}
