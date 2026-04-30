import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/features/settings/viewmodel/settings_viewmodel.dart';

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
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      AppLogo(
                        height: 22,
                        color: Theme.of(context).primaryColor,
                      ),
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              );
            },
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
