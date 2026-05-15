import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:siderapredict/app/core/services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;

  AuthViewModel({required AuthService authService})
    : _authService = authService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _userName;
  String? get userName => _userName;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String emailOrMatricula, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final credentials = await _authService.signIn(
        emailOrMatricula: emailOrMatricula.trim(),
        password: password,
      );
      if (credentials?.user != null) {
        _userName = await _authService.getUserName(credentials!.user!.uid);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _setError('Credenciais inválidas. Verifique seus dados.');
      } else {
        _setError('Erro no login: ${e.message}');
      }
      return false;
    } catch (e) {
      _setError('Ocorreu um erro inesperado.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String matricula,
    required String nome,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final userCredential = await _authService.signUp(
        email: email.trim(),
        password: password,
        matricula: matricula.trim(),
        nome: nome.trim(),
      );
      if (userCredential?.user != null) {
        _userName = nome.trim();
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _setError('Este e-mail já está em uso.');
      } else if (e.code == 'weak-password') {
        _setError('A senha é muito fraca.');
      } else {
        _setError('Erro no cadastro: ${e.message}');
      }
      return false;
    } catch (e) {
      _setError('Ocorreu um erro inesperado.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _userName = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userName = await _authService.getUserName(user.uid);
      notifyListeners();
    }
  }

  Future<bool> checkMatriculaAvailable(String matricula) async {
    _setLoading(true);
    _setError(null);
    try {
      final isAvailable = await _authService.isMatriculaAvailable(
        matricula.trim(),
      );
      if (!isAvailable) {
        _setError('Esta matrícula já está cadastrada.');
      }
      return isAvailable;
    } catch (e) {
      _setError('Erro ao verificar matrícula.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> checkEmailAvailable(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      final isAvailable = await _authService.isEmailAvailable(email.trim());
      if (!isAvailable) {
        _setError('Este e-mail já está em uso.');
      }
      return isAvailable;
    } catch (e) {
      _setError('Erro ao verificar e-mail.');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
