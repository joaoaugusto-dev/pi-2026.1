import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/auth/viewmodel/auth_text_field_view_model.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.suffixIcon,
    this.focusNode,
    this.onSubmitted,
    this.textInputAction,
    this.inputFormatters,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late final AuthTextFieldViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AuthTextFieldViewModel(obscureText: widget.obscureText);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return TextFormField(
          controller: widget.controller,
          obscureText: _viewModel.obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          onChanged: widget.onChanged,
          focusNode: widget.focusNode,
          onFieldSubmitted: widget.onSubmitted,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          style: const TextStyle(color: whiteColor, fontSize: 16),
          cursorColor: whiteColor,
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: TextStyle(color: whiteColor.withValues(alpha: 0.8)),
            prefixIcon: Icon(
              widget.prefixIcon,
              color: whiteColor.withValues(alpha: 0.8),
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _viewModel.visibilityIcon,
                      color: whiteColor.withValues(alpha: 0.8),
                    ),
                    onPressed: _viewModel.toggleObscureTextAction(),
                  )
                : widget.suffixIcon,
            filled: true,
            fillColor: whiteColor.withValues(alpha: 0.1),
            errorStyle: const TextStyle(
              color: Colors.amberAccent,
              fontWeight: FontWeight.bold,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: whiteColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: whiteColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.amberAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.amberAccent, width: 2),
            ),
          ),
        );
      },
    );
  }
}
