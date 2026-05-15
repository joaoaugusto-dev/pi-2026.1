import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/menu/viewmodel/main_menu_view_model.dart';

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MainMenuViewModel>();
    final configIssues = viewModel.configIssues;
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 24,
                        bottom: 24,
                      ),
                      color: theme.brightness == Brightness.light
                          ? theme.primaryColor
                          : theme.appBarTheme.backgroundColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppLogo(
                            height: 26,
                            color: theme.appBarTheme.foregroundColor,
                          ),
                          const SizedBox(width: 24),
                          Text(
                            'MENU PRINCIPAL',
                            style: TextStyle(
                              color: theme.appBarTheme.foregroundColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5,
                              shadows: isHighContrast ? null : textShadows,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text.rich(
                            textAlign: TextAlign.center,
                            TextSpan(
                              style: TextStyle(
                                fontSize: 28,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Olá, ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                                TextSpan(
                                  text: viewModel.firstName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const TextSpan(
                                  text: '!',
                                  style: TextStyle(fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (configIssues.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isHighContrast
                                ? Colors.transparent
                                : const Color(0xFFFFF4E5),
                            borderRadius: isHighContrast
                                ? BorderRadius.zero
                                : BorderRadius.circular(14),
                            border: Border.all(
                              color: isHighContrast
                                  ? theme.colorScheme.primary
                                  : const Color(0xFFE6B566),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ajustes pendentes do .env',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: isHighContrast
                                      ? theme.colorScheme.onSurface
                                      : const Color(0xFF7A4D00),
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final issue in configIssues)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $issue',
                                    style: TextStyle(
                                      color: isHighContrast
                                          ? theme.colorScheme.onSurface
                                          : const Color(0xFF7A4D00),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    Center(
                      child: SizedBox(
                        width: 370,
                        height: 165,
                        child: _MenuCard(
                          icon: Icons.center_focus_strong,
                          title: 'NOVA MEDIÇÃO',
                          onTap: viewModel.newMeasurementAction(context),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      alignment: WrapAlignment.center,
                      children: [
                        SizedBox(
                          width: 175,
                          height: 165,
                          child: _MenuCard(
                            icon: Icons.history,
                            title: 'HISTÓRICO',
                            onTap: viewModel.historyAction(context),
                          ),
                        ),
                        SizedBox(
                          width: 175,
                          height: 165,
                          child: _MenuCard(
                            icon: Icons.settings,
                            title: 'CONFIGURAÇÕES',
                            onTap: viewModel.settingsAction(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: isHighContrast
              ? BorderRadius.zero
              : BorderRadius.circular(20),
          boxShadow: isHighContrast ? null : subtleShadows,
          border: isHighContrast
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: isHighContrast ? null : textShadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
