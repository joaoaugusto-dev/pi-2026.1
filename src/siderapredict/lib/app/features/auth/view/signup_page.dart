import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_background.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_text_field.dart';
import 'package:siderapredict/app/features/auth/view/widgets/password_requirements_widget.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_success_overlay.dart';
import 'package:siderapredict/app/features/auth/viewmodel/signup_view_model.dart';

class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SignupViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          AuthBackground(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 16.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: whiteColor,
                        size: 28,
                      ),
                      onPressed: viewModel.backAction(context),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: List.generate(
                      4,
                      (index) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= viewModel.currentStep
                                ? whiteColor
                                : whiteColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: PageView(
                    controller: viewModel.pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep(
                        title: 'Como podemos te chamar?',
                        subtitle: 'Insira seu nome completo',
                        formKey: viewModel.formKeyNome,
                        child: AuthTextField(
                          controller: viewModel.nomeController,
                          labelText: 'Nome',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          onSubmitted: viewModel.nextStepSubmittedAction(
                            context,
                            viewModel.formKeyNome,
                          ),
                          validator: viewModel.nomeValidator,
                        ),
                        onNext: viewModel.nextStepAction(
                          context,
                          viewModel.formKeyNome,
                        ),
                      ),
                      _buildStep(
                        title: 'Qual a sua matrícula?',
                        subtitle: 'Insira o seu número de identificação',
                        formKey: viewModel.formKeyMatricula,
                        child: AuthTextField(
                          controller: viewModel.matriculaController,
                          labelText: 'Matrícula',
                          prefixIcon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textInputAction: TextInputAction.next,
                          onSubmitted: viewModel.nextStepSubmittedAction(
                            context,
                            viewModel.formKeyMatricula,
                          ),
                          validator: viewModel.matriculaValidator,
                        ),
                        onNext: viewModel.nextStepAction(
                          context,
                          viewModel.formKeyMatricula,
                        ),
                      ),
                      _buildStep(
                        title: 'Qual o seu melhor e-mail?',
                        subtitle: 'Usado para comunicação e recuperação',
                        formKey: viewModel.formKeyEmail,
                        child: AuthTextField(
                          controller: viewModel.emailController,
                          labelText: 'E-mail',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: viewModel.nextStepSubmittedAction(
                            context,
                            viewModel.formKeyEmail,
                          ),
                          validator: viewModel.emailValidator,
                        ),
                        onNext: viewModel.nextStepAction(
                          context,
                          viewModel.formKeyEmail,
                        ),
                      ),
                      _buildStep(
                        title: 'Crie sua senha',
                        subtitle: 'Ela deve ser forte e segura',
                        formKey: viewModel.formKeySenha,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AuthTextField(
                              controller: viewModel.passwordController,
                              labelText: 'Senha',
                              prefixIcon: Icons.lock_outline,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            AuthTextField(
                              controller: viewModel.confirmPasswordController,
                              labelText: 'Confirmar Senha',
                              prefixIcon: Icons.lock_outline,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: viewModel.signupSubmittedAction(
                                context,
                              ),
                              validator: viewModel.confirmPasswordValidator,
                            ),
                            const SizedBox(height: 24),
                            ListenableBuilder(
                              listenable: viewModel.passwordFieldsListenable,
                              builder: (context, child) {
                                return PasswordRequirementsWidget(
                                  password: viewModel.passwordController.text,
                                  confirmPassword:
                                      viewModel.confirmPasswordController.text,
                                );
                              },
                            ),
                          ],
                        ),
                        onNext: viewModel.signupAction(context),
                        isLast: true,
                        isLoading: viewModel.isLoading,
                      ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildStep({
    required String title,
    required String subtitle,
    required GlobalKey<FormState> formKey,
    required Widget child,
    required VoidCallback onNext,
    bool isLast = false,
    bool isLoading = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: whiteColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: whiteColor.withValues(alpha: 0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            child,
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: whiteColor,
                  foregroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isLoading ? null : onNext,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: primaryColor,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isLast ? 'FINALIZAR CADASTRO' : 'AVANÇAR',
                          key: ValueKey<bool>(isLast),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
