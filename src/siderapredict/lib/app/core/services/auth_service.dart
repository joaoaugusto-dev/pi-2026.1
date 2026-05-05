import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential?> signIn({
    required String emailOrMatricula,
    required String password,
  }) async {
    try {
      String email = emailOrMatricula;

      // Check if the input is not an email, then it might be a matricula
      if (!emailOrMatricula.contains('@')) {
        email = await _getEmailFromMatricula(emailOrMatricula);
      }

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      debugPrint('Erro no login: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String matricula,
    required String nome,
  }) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;

        // 1. Save full profile (Protected) - Only name now as email is in its own index
        await _firestore.collection('users').doc(uid).set({
          'nome': nome,
        });

        // 2. Save public index for login by Matricula
        await _firestore.collection('matriculas').doc(matricula).set({
          'email': email,
          'uid': uid,
        });

        // 3. Save public index for Email existence check
        await _firestore.collection('emails').doc(email.trim().toLowerCase()).set({
          'uid': uid,
        });
      }

      return userCredential;
    } catch (e) {
      debugPrint('Erro no cadastro: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<bool> isMatriculaAvailable(String matricula) async {
    final doc = await _firestore.collection('matriculas').doc(matricula.trim()).get();
    return !doc.exists;
  }

  Future<bool> isEmailAvailable(String email) async {
    // Agora buscamos na coleção 'emails' simplificada
    final doc = await _firestore.collection('emails').doc(email.trim().toLowerCase()).get();
    return !doc.exists;
  }

  Future<String?> getUserName(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['nome'] as String?;
  }

  Future<String> _getEmailFromMatricula(String matricula) async {
    // We fetch directly by document ID (matricula)
    // This allows us to set a Firestore rule that allows 'get' but blocks 'list'
    final doc = await _firestore.collection('matriculas').doc(matricula).get();

    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Nenhum usuário encontrado com esta matrícula.',
      );
    }

    return doc.data()?['email'] as String;
  }
}
