import 'package:flutter/material.dart';
import 'package:validatorless/validatorless.dart';

import 'package:siderapredict/app/core/utils/app_alerts.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_view_model.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthViewModel authViewModel})
    : _authViewModel = authViewModel {
    _authViewModel.addListener(notifyListeners);
  }

  final AuthViewModel _authViewModel;

  final formKey = GlobalKey<FormState>();
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();

  bool _showSuccess = false;

  bool get isLoading => _authViewModel.isLoading;
  bool get showSuccess => _showSuccess;
  bool get isLoginDisabled => isLoading || _showSuccess;

  String? identifierValidator(String? value) {
    return Validatorless.multiple([
      Validatorless.required('Campo obrigatório'),
      Validatorless.min(3, 'Identificador muito curto'),
    ])(value);
  }

  String? passwordValidator(String? value) {
    return Validatorless.multiple([
      Validatorless.required('Senha obrigatória'),
      Validatorless.min(8, 'Mínimo de 8 caracteres'),
    ])(value);
  }

  Future<void> onLoginPressed(BuildContext context) async {
    final formValid = formKey.currentState?.validate() ?? false;
    if (!formValid) return;

    final success = await _authViewModel.login(
      identifierController.text,
      passwordController.text,
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

  VoidCallback loginAction(BuildContext context) {
    return () => onLoginPressed(context);
  }

  ValueChanged<String> loginSubmittedAction(BuildContext context) {
    return (_) => onLoginPressed(context);
  }

  VoidCallback signupAction(BuildContext context) {
    return () => onSignupPressed(context);
  }

  VoidCallback successCompleteAction(BuildContext context) {
    return () => onSuccessComplete(context);
  }

  void onSignupPressed(BuildContext context) {
    _authViewModel.clearError();
    Navigator.of(context).pushNamed(AppRoutes.signup);
  }

  void onSuccessComplete(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.menuPrincipal);
  }

  @override
  void dispose() {
    _authViewModel.removeListener(notifyListeners);
    identifierController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
