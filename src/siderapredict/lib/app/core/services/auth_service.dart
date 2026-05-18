import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthenticatedUser {
  const AuthenticatedUser({required this.uid, this.email, this.name});

  final String uid;
  final String? email;
  final String? name;
}

class AuthResult {
  const AuthResult({this.user});

  final AuthenticatedUser? user;
}

class AuthServiceException implements Exception {
  const AuthServiceException({required this.code, this.message});

  final String code;
  final String? message;

  @override
  String toString() => message == null
      ? 'AuthServiceException($code)'
      : 'AuthServiceException($code, $message)';
}

class AuthService {
  AuthService({supabase.SupabaseClient? client}) : _client = client;

  final supabase.SupabaseClient? _client;

  supabase.SupabaseClient? get _maybeClient {
    final client = _client;
    if (client != null) return client;

    try {
      return supabase.Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  supabase.SupabaseClient get _supabase {
    final client = _maybeClient;
    if (client == null) {
      throw const AuthServiceException(
        code: 'not-configured',
        message: 'Supabase não foi inicializado.',
      );
    }
    return client;
  }

  Stream<AuthenticatedUser?> get authStateChanges {
    final client = _maybeClient;
    if (client == null) return Stream.value(null);

    return client.auth.onAuthStateChange.map(
      (state) => _toAuthenticatedUser(state.session?.user),
    );
  }

  AuthenticatedUser? get currentUser =>
      _toAuthenticatedUser(_maybeClient?.auth.currentUser);

  Future<AuthResult?> signIn({
    required String emailOrMatricula,
    required String password,
  }) async {
    try {
      String email = emailOrMatricula;

      // Check if the input is not an email, then it might be a matricula
      if (!emailOrMatricula.contains('@')) {
        email = await _getEmailFromMatricula(emailOrMatricula);
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return AuthResult(user: _toAuthenticatedUser(response.user));
    } on AuthServiceException {
      rethrow;
    } on supabase.AuthException catch (e) {
      throw _mapAuthException(e);
    } on supabase.PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      debugPrint('Erro no login: $e');
      rethrow;
    }
  }

  Future<AuthResult?> signUp({
    required String email,
    required String password,
    required String matricula,
    required String nome,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedMatricula = matricula.trim();
      final normalizedNome = nome.trim();

      if (!await isEmailAvailable(normalizedEmail)) {
        throw const AuthServiceException(code: 'email-already-in-use');
      }
      if (!await isMatriculaAvailable(normalizedMatricula)) {
        throw const AuthServiceException(code: 'matricula-already-in-use');
      }

      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: <String, dynamic>{
          'nome': normalizedNome,
          'matricula': normalizedMatricula,
        },
      );
      return AuthResult(user: _toAuthenticatedUser(response.user));
    } on AuthServiceException {
      rethrow;
    } on supabase.AuthException catch (e) {
      throw _mapAuthException(e);
    } on supabase.PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      debugPrint('Erro no cadastro: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<bool> isMatriculaAvailable(String matricula) async {
    final result = await _supabase.rpc(
      'is_matricula_available',
      params: <String, dynamic>{'matricula_input': matricula.trim()},
    );
    return result == true;
  }

  Future<bool> isEmailAvailable(String email) async {
    final result = await _supabase.rpc(
      'is_email_available',
      params: <String, dynamic>{'email_input': email.trim().toLowerCase()},
    );
    return result == true;
  }

  Future<String?> getUserName(String uid) async {
    final data = await _supabase
        .from('profiles')
        .select('nome')
        .eq('id', uid)
        .maybeSingle();
    return data?['nome'] as String?;
  }

  Future<String> _getEmailFromMatricula(String matricula) async {
    final result = await _supabase.rpc(
      'email_for_matricula',
      params: <String, dynamic>{'matricula_input': matricula.trim()},
    );

    final email = result as String?;
    if (email == null || email.trim().isEmpty) {
      throw const AuthServiceException(
        code: 'user-not-found',
        message: 'Nenhum usuário encontrado com esta matrícula.',
      );
    }

    return email;
  }

  AuthenticatedUser? _toAuthenticatedUser(supabase.User? user) {
    if (user == null) return null;
    return AuthenticatedUser(
      uid: user.id,
      email: user.email,
      name: user.userMetadata?['nome'] as String?,
    );
  }

  AuthServiceException _mapAuthException(supabase.AuthException exception) {
    final rawCode = exception.code ?? '';
    final message = exception.message;
    final normalizedMessage = message.toLowerCase();

    if (rawCode == 'invalid_credentials' ||
        normalizedMessage.contains('invalid login credentials')) {
      return AuthServiceException(code: 'invalid-credential', message: message);
    }
    if (rawCode == 'user_already_exists' ||
        normalizedMessage.contains('already registered')) {
      return AuthServiceException(
        code: 'email-already-in-use',
        message: message,
      );
    }
    if (rawCode == 'weak_password' ||
        normalizedMessage.contains('weak password')) {
      return AuthServiceException(code: 'weak-password', message: message);
    }
    if (rawCode == 'email_not_confirmed' ||
        normalizedMessage.contains('email not confirmed') ||
        normalizedMessage.contains('not confirmed')) {
      return const AuthServiceException(code: 'invalid-credential');
    }

    return AuthServiceException(
      code: rawCode.isEmpty ? 'auth-error' : rawCode,
      message: message,
    );
  }

  AuthServiceException _mapPostgrestException(
    supabase.PostgrestException exception,
  ) {
    return AuthServiceException(
      code: exception.code ?? 'database-error',
      message: exception.message,
    );
  }
}
