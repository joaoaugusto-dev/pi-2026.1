import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:validatorless/validatorless.dart';

import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:siderapredict/app/routes/app_routes.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_background.dart';
import 'package:siderapredict/app/features/auth/view/widgets/premium_text_field.dart';

import 'package:siderapredict/app/core/utils/premium_alerts.dart';

import 'package:siderapredict/app/features/auth/view/widgets/success_overlay.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierEC = TextEditingController();
  final _passwordEC = TextEditingController();
  bool _showSuccess = false;

  @override
  void dispose() {
    _identifierEC.dispose();
    _passwordEC.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final viewModel = context.read<AuthViewModel>();
      final success = await viewModel.login(_identifierEC.text, _passwordEC.text);

      if (success && mounted) {
        setState(() => _showSuccess = true);
      } else if (mounted && viewModel.errorMessage != null) {
        PremiumAlerts.showError(context, viewModel.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          AuthBackground(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogo(height: 100),
                      const SizedBox(height: 16),
                      const Text(
                        'BEM-VINDO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: whiteColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 4,
                          shadows: textShadows,
                        ),
                      ),
                      const SizedBox(height: 48),

                      PremiumTextField(
                        controller: _identifierEC,
                        labelText: 'E-mail ou Matrícula',
                        prefixIcon: Icons.person_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validatorless.multiple([
                          Validatorless.required('Campo obrigatório'),
                          Validatorless.min(3, 'Identificador muito curto'),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      PremiumTextField(
                        controller: _passwordEC,
                        labelText: 'Senha',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        validator: Validatorless.multiple([
                          Validatorless.required('Senha obrigatória'),
                          Validatorless.min(8, 'Mínimo de 8 caracteres'),
                        ]),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: whiteColor,
                            foregroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: viewModel.isLoading || _showSuccess ? null : _login,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: viewModel.isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: primaryColor,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'ENTRAR',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          viewModel.clearError();
                          viewModel.setSignupStep(0);
                          Navigator.of(context).pushNamed(AppRoutes.signup);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: whiteColor,
                        ),
                        child: const Text(
                          'Não tem uma conta? Cadastre-se',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SuccessOverlay(
            visible: _showSuccess,
            onComplete: () {
              Navigator.of(context).pushReplacementNamed(AppRoutes.menuPrincipal);
            },
          ),
        ],
      ),
    );
  }
}
