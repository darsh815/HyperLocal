import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AccountSession {
  const AccountSession({
    required this.token,
    required this.email,
    this.role = 'user',
  });

  final String token;
  final String email;
  final String role;
  bool get isAdmin => role == 'admin';
}

class AccountService {
  static Future<void>? _googleSignInInitialization;

  bool get _usesFirebase => Firebase.apps.isNotEmpty;
  bool get usesFirebase => _usesFirebase;
  bool get isConfigured => _usesFirebase;

  Future<AccountSession?> restoreSession() async {
    if (!_usesFirebase) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    if (await _isBanned(user)) {
      await FirebaseAuth.instance.signOut();
      return null;
    }
    return _firebaseSession(user);
  }

  Future<AccountSession> register(String email, String password) async {
    _requireFirebase();
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      final user = credential.user;
      if (user == null) throw Exception('Firebase did not create an account.');
      await _createUserProfile(user);
      return await _firebaseSession(user);
    } on FirebaseAuthException catch (error) {
      throw Exception(
        error.message ?? 'Unable to create your Firebase account.',
      );
    }
  }

  Future<AccountSession> login(String email, String password) async {
    _requireFirebase();
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('Firebase did not return an account.');
      await _ensureNotBanned(user);
      return await _firebaseSession(user);
    } on FirebaseAuthException catch (error) {
      throw Exception(error.message ?? 'Unable to sign in to Firebase.');
    }
  }

  Future<AccountSession> signInWithGoogle() async {
    _requireFirebase();
    try {
      late UserCredential credential;
      if (kIsWeb) {
        credential = await FirebaseAuth.instance.signInWithPopup(
          GoogleAuthProvider(),
        );
      } else {
        await (_googleSignInInitialization ??= GoogleSignIn.instance
            .initialize());
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;
        final providerCredential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        credential = await FirebaseAuth.instance.signInWithCredential(
          providerCredential,
        );
      }
      final user = credential.user;
      if (user == null) {
        throw Exception('Firebase did not return a Google account.');
      }
      await _ensureNotBanned(user);
      await _createUserProfile(user);
      return await _firebaseSession(user);
    } on FirebaseAuthException catch (error) {
      throw Exception(error.message ?? 'Google sign-in failed.');
    } catch (error) {
      throw Exception(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<List<Map<String, dynamic>>> loadHistory(String token) async {
    final user = _currentUser();
    final snapshots = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recipes')
        .orderBy('savedAt', descending: true)
        .get();
    return snapshots.docs.map((document) {
      final data = Map<String, dynamic>.from(document.data());
      final savedAt = data['savedAt'];
      data['id'] = document.id;
      data['savedAt'] = savedAt is Timestamp
          ? savedAt.toDate().toIso8601String()
          : DateTime.now().toIso8601String();
      return data;
    }).toList();
  }

  Future<String> saveRecipe(String token, Map<String, dynamic> recipe) async {
    final user = _currentUser();
    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recipes')
        .add({...recipe, 'savedAt': FieldValue.serverTimestamp()});
    return document.id;
  }

  Future<void> deleteRecipe(String token, String id) async {
    final user = _currentUser();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('recipes')
        .doc(id)
        .delete();
  }

  Future<void> setUserBanned(String userId, bool banned) async {
    _requireFirebase();
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'banned': banned,
      'bannedAt': banned ? FieldValue.serverTimestamp() : FieldValue.delete(),
    });
  }

  Future<void> saveSession(AccountSession session) async {}

  Future<void> clearSession() async {
    if (_usesFirebase) await FirebaseAuth.instance.signOut();
  }

  Future<void> _createUserProfile(User user) =>
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<bool> _isBanned(User user) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return snapshot.data()?['banned'] == true;
  }

  Future<void> _ensureNotBanned(User user) async {
    if (await _isBanned(user)) {
      await FirebaseAuth.instance.signOut();
      throw Exception('This account has been banned.');
    }
  }

  Future<AccountSession> _firebaseSession(User user) async {
    final tokenResult = await user.getIdTokenResult(true);
    final claims = tokenResult.claims ?? const <String, dynamic>{};
    final isAdmin = claims['admin'] == true || claims['role'] == 'admin';
    return AccountSession(
      token: tokenResult.token ?? user.uid,
      email: user.email ?? '',
      role: isAdmin ? 'admin' : 'user',
    );
  }

  User _currentUser() {
    _requireFirebase();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please sign in again.');
    return user;
  }

  void _requireFirebase() {
    if (!_usesFirebase) {
      throw Exception('Firebase is not configured for this app build.');
    }
  }

  void dispose() {}
}
