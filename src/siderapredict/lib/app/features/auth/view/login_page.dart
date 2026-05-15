import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_background.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_text_field.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_success_overlay.dart';
import 'package:siderapredict/app/features/auth/viewmodel/login_view_model.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          AuthBackground(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: viewModel.formKey,
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

                      AuthTextField(
                        controller: viewModel.identifierController,
                        labelText: 'E-mail ou Matrícula',
                        prefixIcon: Icons.person_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: viewModel.identifierValidator,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        controller: viewModel.passwordController,
                        labelText: 'Senha',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: viewModel.loginSubmittedAction(context),
                        validator: viewModel.passwordValidator,
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
                          onPressed: viewModel.isLoginDisabled
                              ? null
                              : viewModel.loginAction(context),
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
                        onPressed: viewModel.signupAction(context),
                        style: TextButton.styleFrom(
                          foregroundColor: whiteColor,
                        ),
                        child: const Text(
                          'Não tem uma conta? Cadastre-se',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AuthSuccessOverlay(
            visible: viewModel.showSuccess,
            onComplete: viewModel.successCompleteAction(context),
          ),
        ],
      ),
    );
  }
}
