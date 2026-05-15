import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siderapredict/app/core/widgets/primary_action_button.dart';
import 'package:siderapredict/app/features/auth/view/widgets/auth_text_field.dart';
import 'package:siderapredict/app/features/auth/view/widgets/password_requirements_widget.dart';

void main() {
  group('Widgets - Testes de Componente', () {
    testWidgets('TC28 - AuthTextField alterna visibilidade da senha', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Senha123!');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthTextField(
              controller: controller,
              labelText: 'Senha',
              prefixIcon: Icons.lock,
              obscureText: true,
            ),
          ),
        ),
      );

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue,
      );
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(
        tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isFalse,
      );
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('TC29 - PasswordRequirementsWidget mostra regras de senha', (
      tester,
    ) async {
      const widget = PasswordRequirementsWidget(
        password: 'Senha123!',
        confirmPassword: 'Senha123!',
      );

      expect(widget.hasMinLength, isTrue);
      expect(widget.hasUppercase, isTrue);
      expect(widget.hasNumber, isTrue);
      expect(widget.hasSpecial, isTrue);
      expect(widget.passwordsMatch, isTrue);

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: widget)));

      expect(find.text('Segurança da senha'), findsOneWidget);
      expect(find.text('Mínimo de 8 caracteres'), findsOneWidget);
      expect(find.text('Uma letra maiúscula'), findsOneWidget);
      expect(find.text('Um número'), findsOneWidget);
      expect(find.text('Um caractere especial'), findsOneWidget);
      expect(find.text('As senhas coincidem'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
    });

    testWidgets('TC30 - PrimaryActionButton alterna estados normal e loading', (
      tester,
    ) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryActionButton(
              label: 'Salvar',
              icon: Icons.save,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Salvar'));
      expect(pressed, isTrue);
      expect(find.byIcon(Icons.save), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrimaryActionButton(
              label: 'Salvar',
              onPressed: null,
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Salvar'), findsNothing);
    });
  });
}
