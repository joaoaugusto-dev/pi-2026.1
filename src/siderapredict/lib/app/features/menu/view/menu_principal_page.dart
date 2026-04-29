import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/routes/app_pages.dart';
import 'package:siderapredict/app/routes/app_routes.dart';
import 'package:siderapredict/app/config/app_config.dart';
import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/inspection_viewmodel.dart';

class MenuPrincipalPage extends StatelessWidget {
  const MenuPrincipalPage({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final viewModel = context.read<InspectionViewModel>();
    final configIssues = AppConfig.validationMessages;

    return Scaffold(
      backgroundColor: primaryColor,
      body: SafeArea(
        child: Container(
          color: backgroundLight,
          child: Column(
            children: [
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                color: primaryColor,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppLogo(height: 26),
                    SizedBox(width: 24),
                    Text(
                      'MENU PRINCIPAL',
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        shadows: textShadows,
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
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE6B566)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ajustes pendentes do .env',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7A4D00),
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final issue in configIssues)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $issue',
                              style: const TextStyle(
                                color: Color(0xFF7A4D00),
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 40),

              
              SizedBox(
                width: 370,
                height: 165,
                child: _MenuCard(
                  icon: Icons.center_focus_strong,
                  title: 'NOVA MEDIÇÃO',
                  onTap: () {
                    viewModel.clearDraft();
                    Navigator.of(context).pushNamed(
                      AppRoutes.camera,
                      arguments: CameraArgs(
                        cameras: viewModel.availableCameras,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 175,
                    height: 165,
                    child: _MenuCard(
                      icon: Icons.history,
                      title: 'HISTÓRICO',
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.history),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 175,
                    height: 165,
                    child: _MenuCard(
                      icon: Icons.info_outline,
                      title: 'SOBRE',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Row(
                              children: [
                                AppLogo(height: 22, color: primaryColor),
                                SizedBox(width: 24),
                                Flexible(
                                  child: Text(
                                    'Sidera Predict',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: darkTextColor,
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
                                  'Versão 1.0',
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
                  ),
                ],
              ),
            ],
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: whiteColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: subtleShadows,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: darkTextColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: darkTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: textShadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
