import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:validatorless/validatorless.dart';

import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:siderapredict/app/routes/app_routes.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_background.dart';
import 'package:siderapredict/app/features/auth/view/widgets/premium_text_field.dart';
import 'package:siderapredict/app/features/auth/view/widgets/password_validator_widget.dart';

import 'package:siderapredict/app/core/utils/premium_alerts.dart';

import 'package:siderapredict/app/features/auth/view/widgets/success_overlay.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _nomeEC = TextEditingController();
  final _matriculaEC = TextEditingController();
  final _emailEC = TextEditingController();
  final _passwordEC = TextEditingController();
  final _confirmPasswordEC = TextEditingController();

  final _formKeyNome = GlobalKey<FormState>();
  final _formKeyMatricula = GlobalKey<FormState>();
  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeySenha = GlobalKey<FormState>();
  final _formKeyConfirm = GlobalKey<FormState>();

  final _pageController = PageController();
  int _currentStep = 0;
  bool _showSuccess = false;

  @override
  void dispose() {
    _nomeEC.dispose();
    _matriculaEC.dispose();
    _emailEC.dispose();
    _passwordEC.dispose();
    _confirmPasswordEC.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep(AuthViewModel viewModel, GlobalKey<FormState> formKey) async {
    if (formKey.currentState?.validate() ?? false) {
      // 1. Check Matricula uniqueness
      if (_currentStep == 1) {
        final available = await viewModel.checkMatriculaAvailable(_matriculaEC.text);
        if (!available && mounted) {
          PremiumAlerts.showError(context, viewModel.errorMessage ?? 'Matrícula indisponível');
          return;
        }
      }

      // 2. Check Email uniqueness
      if (_currentStep == 2) {
        final available = await viewModel.checkEmailAvailable(_emailEC.text);
        if (!available && mounted) {
          PremiumAlerts.showError(context, viewModel.errorMessage ?? 'E-mail indisponível');
          return;
        }
      }

      // 3. Password rule validation
      if (_currentStep == 3) {
        final pwd = _passwordEC.text;
        if (pwd.length < 8 || !pwd.contains(RegExp(r'[A-Z]')) || !pwd.contains(RegExp(r'[0-9]')) || !pwd.contains(RegExp(r'[!@#\$&*~_.,^\-+=\|/\\(){}\[\]]'))) {
           return; 
        }
      }

      viewModel.clearError();
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _prevStep(AuthViewModel viewModel) {
    viewModel.clearError();
    setState(() => _currentStep--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _signup(AuthViewModel viewModel) async {
    if (_formKeyConfirm.currentState?.validate() ?? false) {
      final success = await viewModel.signUp(
        email: _emailEC.text,
        password: _passwordEC.text,
        matricula: _matriculaEC.text,
        nome: _nomeEC.text,
      );

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
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 16.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: whiteColor, size: 28),
                      onPressed: () {
                        if (_currentStep > 0) {
                          _prevStep(viewModel);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: List.generate(5, (index) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 4,
                        decoration: BoxDecoration(
                          color: index <= _currentStep ? whiteColor : whiteColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep(
                        title: 'Como podemos te chamar?',
                        subtitle: 'Insira seu nome completo',
                        formKey: _formKeyNome,
                        child: PremiumTextField(
                          controller: _nomeEC,
                          labelText: 'Nome',
                          prefixIcon: Icons.person_outline,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _nextStep(viewModel, _formKeyNome),
                          validator: Validatorless.required('Nome obrigatório'),
                        ),
                        onNext: () => _nextStep(viewModel, _formKeyNome),
                      ),
                      _buildStep(
                        title: 'Qual a sua matrícula?',
                        subtitle: 'Insira o seu número de identificação',
                        formKey: _formKeyMatricula,
                        child: PremiumTextField(
                          controller: _matriculaEC,
                          labelText: 'Matrícula',
                          prefixIcon: Icons.badge_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _nextStep(viewModel, _formKeyMatricula),
                          validator: Validatorless.multiple([
                            Validatorless.required('Matrícula obrigatória'),
                            Validatorless.min(3, 'Matrícula muito curta'),
                            Validatorless.number('Apenas números são permitidos'),
                          ]),
                        ),
                        onNext: () => _nextStep(viewModel, _formKeyMatricula),
                      ),
                      _buildStep(
                        title: 'Qual o seu melhor e-mail?',
                        subtitle: 'Usado para comunicação e recuperação',
                        formKey: _formKeyEmail,
                        child: PremiumTextField(
                          controller: _emailEC,
                          labelText: 'E-mail',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _nextStep(viewModel, _formKeyEmail),
                          validator: Validatorless.multiple([
                            Validatorless.required('E-mail obrigatório'),
                            Validatorless.email('E-mail inválido'),
                          ]),
                        ),
                        onNext: () => _nextStep(viewModel, _formKeyEmail),
                      ),
                      _buildStep(
                        title: 'Crie uma senha forte',
                        subtitle: 'Ela deve seguir as regras de segurança',
                        formKey: _formKeySenha,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PremiumTextField(
                              controller: _passwordEC,
                              labelText: 'Senha',
                              prefixIcon: Icons.lock_outline,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _nextStep(viewModel, _formKeySenha),
                            ),
                            const SizedBox(height: 16),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _passwordEC,
                              builder: (context, value, child) {
                                return PasswordValidatorWidget(password: value.text);
                              },
                            ),
                          ],
                        ),
                        onNext: () => _nextStep(viewModel, _formKeySenha),
                      ),
                      _buildStep(
                        title: 'Confirme sua senha',
                        subtitle: 'Para garantir que você não digitou errado',
                        formKey: _formKeyConfirm,
                        child: PremiumTextField(
                          controller: _confirmPasswordEC,
                          labelText: 'Confirmar Senha',
                          prefixIcon: Icons.lock_outline,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signup(viewModel),
                          validator: Validatorless.multiple([
                            Validatorless.required('Confirmação obrigatória'),
                            Validatorless.compare(_passwordEC, 'As senhas não coincidem'),
                          ]),
                        ),
                        onNext: () => _signup(viewModel),
                        isLast: true,
                        isLoading: viewModel.isLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SuccessOverlay(
            visible: _showSuccess,
            onComplete: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.menuPrincipal,
                (route) => false,
              );
            },
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
