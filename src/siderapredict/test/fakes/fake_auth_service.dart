import 'dart:async';

import 'package:siderapredict/app/core/services/auth_service.dart';

/// Implementação fake do AuthService para testes.
/// Armazena usuários em memória e simula login/cadastro
/// sem dependência do Supabase.
class FakeAuthService extends AuthService {
  FakeAuthService() : super(client: null);

  // Armazena usuários cadastrados: chave = email
  final Map<String, _FakeUser> _users = {};
  // Armazena matrícula -> email
  final Map<String, String> _matriculas = {};

  AuthenticatedUser? _currentUser;

  final _authStateController =
      StreamController<AuthenticatedUser?>.broadcast();

  @override
  Stream<AuthenticatedUser?> get authStateChanges =>
      _authStateController.stream;

  @override
  AuthenticatedUser? get currentUser => _currentUser;

  @override
  Future<AuthResult?> signIn({
    required String emailOrMatricula,
    required String password,
  }) async {
    String email = emailOrMatricula;

    // Se não contém @, tenta buscar pela matrícula
    if (!emailOrMatricula.contains('@')) {
      final found = _matriculas[emailOrMatricula.trim()];
      if (found == null) {
        throw const AuthServiceException(
          code: 'user-not-found',
          message: 'Nenhum usuário encontrado com esta matrícula.',
        );
      }
      email = found;
    }

    final user = _users[email.trim().toLowerCase()];
    if (user == null) {
      throw const AuthServiceException(
        code: 'user-not-found',
        message: 'Usuário não encontrado.',
      );
    }

    if (user.password != password) {
      throw const AuthServiceException(
        code: 'invalid-credential',
        message: 'Credenciais inválidas.',
      );
    }

    _currentUser = AuthenticatedUser(
      uid: user.uid,
      email: user.email,
      name: user.nome,
    );
    _authStateController.add(_currentUser);

    return AuthResult(user: _currentUser);
  }

  @override
  Future<AuthResult?> signUp({
    required String email,
    required String password,
    required String matricula,
    required String nome,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedMatricula = matricula.trim();

    if (_users.containsKey(normalizedEmail)) {
      throw const AuthServiceException(code: 'email-already-in-use');
    }

    if (_matriculas.containsKey(normalizedMatricula)) {
      throw const AuthServiceException(code: 'matricula-already-in-use');
    }

    final uid = 'fake-uid-${_users.length + 1}';
    final fakeUser = _FakeUser(
      uid: uid,
      email: normalizedEmail,
      password: password,
      matricula: normalizedMatricula,
      nome: nome.trim(),
    );

    _users[normalizedEmail] = fakeUser;
    _matriculas[normalizedMatricula] = normalizedEmail;

    _currentUser = AuthenticatedUser(
      uid: uid,
      email: normalizedEmail,
      name: nome.trim(),
    );
    _authStateController.add(_currentUser);

    return AuthResult(user: _currentUser);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<bool> isMatriculaAvailable(String matricula) async {
    return !_matriculas.containsKey(matricula.trim());
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    return !_users.containsKey(email.trim().toLowerCase());
  }

  @override
  Future<String?> getUserName(String uid) async {
    for (final user in _users.values) {
      if (user.uid == uid) {
        return user.nome;
      }
    }
    return null;
  }

  void dispose() {
    _authStateController.close();
  }
}

class _FakeUser {
  const _FakeUser({
    required this.uid,
    required this.email,
    required this.password,
    required this.matricula,
    required this.nome,
  });

  final String uid;
  final String email;
  final String password;
  final String matricula;
  final String nome;
}
