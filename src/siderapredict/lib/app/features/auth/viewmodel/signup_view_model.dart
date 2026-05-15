import 'package:flutter/material.dart';
import 'package:validatorless/validatorless.dart';

import 'package:siderapredict/app/core/utils/app_alerts.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

class SignupViewModel extends ChangeNotifier {
  SignupViewModel({required AuthViewModel authViewModel})
    : _authViewModel = authViewModel {
    _authViewModel.addListener(notifyListeners);
    passwordFieldsListenable = Listenable.merge([
      passwordController,
      confirmPasswordController,
    ]);
  }

  final AuthViewModel _authViewModel;

  final nomeController = TextEditingController();
  final matriculaController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final formKeyNome = GlobalKey<FormState>();
  final formKeyMatricula = GlobalKey<FormState>();
  final formKeyEmail = GlobalKey<FormState>();
  final formKeySenha = GlobalKey<FormState>();
  final pageController = PageController();

  late final Listenable passwordFieldsListenable;

  int _currentStep = 0;
  bool _showSuccess = false;

  int get currentStep => _currentStep;
  bool get showSuccess => _showSuccess;
  bool get isLoading => _authViewModel.isLoading;

  String? nomeValidator(String? value) {
    return Validatorless.required('Nome obrigatório')(value);
  }

  String? matriculaValidator(String? value) {
    return Validatorless.multiple([
      Validatorless.required('Matrícula obrigatória'),
      Validatorless.min(3, 'Matrícula muito curta'),
      Validatorless.number('Apenas números são permitidos'),
    ])(value);
  }

  String? emailValidator(String? value) {
    return Validatorless.multiple([
      Validatorless.required('E-mail obrigatório'),
      Validatorless.email('E-mail inválido'),
    ])(value);
  }

  String? confirmPasswordValidator(String? value) {
    return Validatorless.multiple([
      Validatorless.required('Confirmação obrigatória'),
      Validatorless.compare(passwordController, 'As senhas não coincidem'),
    ])(value);
  }

  bool get isPasswordStrong {
    final password = passwordController.text;
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[!@#\$&*~_.,^\-+=\|/\\(){}\[\]]'));
  }

  Future<void> onNextStepPressed(
    BuildContext context,
    GlobalKey<FormState> formKey,
  ) async {
    final formValid = formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    if (_currentStep == 1) {
      final available = await _authViewModel.checkMatriculaAvailable(
        matriculaController.text,
      );
      if (!available) {
        if (context.mounted) {
          AppAlerts.showError(
            context,
            _authViewModel.errorMessage ?? 'Matrícula indisponível',
          );
        }
        return;
      }
    }

    if (_currentStep == 2) {
      final available = await _authViewModel.checkEmailAvailable(
        emailController.text,
      );
      if (!available) {
        if (context.mounted) {
          AppAlerts.showError(
            context,
            _authViewModel.errorMessage ?? 'E-mail indisponível',
          );
        }
        return;
      }
    }

    _authViewModel.clearError();
    _currentStep++;
    notifyListeners();
    await pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> onPreviousStepPressed() async {
    if (_currentStep <= 0) return;

    _authViewModel.clearError();
    _currentStep--;
    notifyListeners();
    await pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> onBackPressed(BuildContext context) async {
    if (_currentStep > 0) {
      await onPreviousStepPressed();
      return;
    }

    Navigator.of(context).pop();
  }

  VoidCallback backAction(BuildContext context) {
    return () => onBackPressed(context);
  }

  VoidCallback nextStepAction(
    BuildContext context,
    GlobalKey<FormState> formKey,
  ) {
    return () => onNextStepPressed(context, formKey);
  }

  ValueChanged<String> nextStepSubmittedAction(
    BuildContext context,
    GlobalKey<FormState> formKey,
  ) {
    return (_) => onNextStepPressed(context, formKey);
  }

  VoidCallback signupAction(BuildContext context) {
    return () => onSignupPressed(context);
  }

  ValueChanged<String> signupSubmittedAction(BuildContext context) {
    return (_) => onSignupPressed(context);
  }

  VoidCallback successCompleteAction(BuildContext context) {
    return () => onSuccessComplete(context);
  }

  Future<void> onSignupPressed(BuildContext context) async {
    final formValid = formKeySenha.currentState?.validate() ?? false;
    if (!formValid || !isPasswordStrong) return;

    final success = await _authViewModel.signUp(
      email: emailController.text,
      password: passwordController.text,
      matricula: matriculaController.text,
      nome: nomeController.text,
    );

    if (!context.mounted) return;

    if (success) {
      _showSuccess = true;
      notifyListeners();
      return;
    }

    final errorMessage = _authViewModel.errorMessage;
    if (errorMessage != null) {
      AppAlerts.showError(context, errorMessage);
    }
  }

  void onSuccessComplete(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.menuPrincipal, (route) => false);
  }

  @override
  void dispose() {
    _authViewModel.removeListener(notifyListeners);
    nomeController.dispose();
    matriculaController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    pageController.dispose();
    super.dispose();
  }
}
