import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/settings/viewmodel/settings_view_model.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SettingsViewModel>();

    return Scaffold(
      appBar: buildAppBar(context: context, title: 'Configurações'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Aparência'),
          _buildSettingTile(
            title: 'Modo Escuro',
            subtitle: 'Alternar entre tema claro e escuro',
            icon: Icons.dark_mode,
            value: viewModel.isDarkMode,
            onChanged: viewModel.toggleDarkMode,
          ),
          const Divider(),
          _buildSettingTile(
            title: 'Alto Contraste',
            subtitle: 'Cores mais nítidas para melhor acessibilidade',
            icon: Icons.accessibility_new,
            value: viewModel.isHighContrast,
            onChanged: viewModel.toggleHighContrast,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Sobre'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sidera Predict'),
            subtitle: const Text('Mais informações sobre o aplicativo'),
            onTap: viewModel.aboutAction(context),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Conta'),
          ListTile(
            leading: const Icon(Icons.logout, color: paletteRed),
            title: const Text(
              'Sair da Conta',
              style: TextStyle(color: paletteRed, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Encerrar sua sessão atual'),
            onTap: viewModel.logoutAction(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: primaryColor,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: primaryColor,
      ),
    );
  }
}
