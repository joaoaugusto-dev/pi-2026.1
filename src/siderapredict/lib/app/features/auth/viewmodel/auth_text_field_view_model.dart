import 'package:flutter/material.dart';

class AuthTextFieldViewModel extends ChangeNotifier {
  AuthTextFieldViewModel({required bool obscureText})
    : _obscureText = obscureText;

  bool _obscureText;

  bool get obscureText => _obscureText;
  IconData get visibilityIcon =>
      _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined;

  void toggleObscureText() {
    _obscureText = !_obscureText;
    notifyListeners();
  }

  VoidCallback toggleObscureTextAction() {
    return toggleObscureText;
  }
}
