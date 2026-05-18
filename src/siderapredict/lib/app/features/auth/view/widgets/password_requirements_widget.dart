import 'package:flutter/material.dart';
import 'package:siderapredict/app/core/theme/app_theme.dart';

class PasswordRequirementsWidget extends StatelessWidget {
  final String password;
  final String confirmPassword;

  const PasswordRequirementsWidget({
    super.key,
    required this.password,
    required this.confirmPassword,
  });

  bool get hasMinLength => password.length >= 8;
  bool get hasUppercase => password.contains(RegExp(r'[A-Z]'));
  bool get hasNumber => password.contains(RegExp(r'[0-9]'));
  bool get hasSpecial =>
      password.contains(RegExp(r'[!@#\$&*~_.,^\-+=\|/\\(){}\[\]]'));
  bool get passwordsMatch => password.isNotEmpty && password == confirmPassword;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: whiteColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: whiteColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: whiteColor.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Segurança da senha',
                style: TextStyle(
                  color: whiteColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRule('Mínimo de 8 caracteres', hasMinLength),
          _buildRule('Uma letra maiúscula', hasUppercase),
          _buildRule('Um número', hasNumber),
          _buildRule('Um caractere especial', hasSpecial),
          _buildRule('As senhas coincidem', passwordsMatch),
        ],
      ),
    );
  }

  Widget _buildRule(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              isValid ? Icons.check_circle : Icons.circle_outlined,
              key: ValueKey<bool>(isValid),
              color: isValid ? confirmGreen : whiteColor.withValues(alpha: 0.3),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                color: isValid ? whiteColor : whiteColor.withValues(alpha: 0.4),
                fontSize: 14,
                fontWeight: isValid ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}
