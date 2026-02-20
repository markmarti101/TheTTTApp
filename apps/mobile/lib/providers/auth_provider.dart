import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef UserRole = String; // 'training_company' | 'freelance_trainer' | 'client'

class AuthProvider extends ChangeNotifier {
  User? _user;
  UserRole? _role;
  bool _loading = true;
  String? _error;

  User? get user => _user;
  UserRole? get role => _role;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null && _role != null;

  AuthProvider() {
    _init();
  }

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      _user = user;
      _error = null;
      if (user != null) {
        _role = await _fetchRole(user.uid);
        if (_role == null) {
          await FirebaseAuth.instance.signOut();
          _user = null;
          _role = null;
        }
      } else {
        _role = null;
      }
      _loading = false;
      notifyListeners();
    });
  }

  Future<UserRole?> _fetchRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final role = doc.data()?['role'] as String?;
      if (role != null &&
          ['training_company', 'freelance_trainer', 'client'].contains(role)) {
        return role;
      }
    } catch (_) {}
    return null;
  }

  Future<void> signUp(String email, String password, UserRole role) async {
    _error = null;
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final uid = cred.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'role': role,
        });
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _error = 'An account already exists with this email';
      } else if (e.code == 'weak-password') {
        _error = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        _error = 'Please enter a valid email address';
      } else {
        _error = e.message ?? 'Sign up failed';
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    _error = null;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        _error = 'Invalid email or password';
      } else if (e.code == 'user-not-found') {
        _error = 'No account found with this email';
      } else if (e.code == 'invalid-email') {
        _error = 'Please enter a valid email address';
      } else {
        _error = e.message ?? 'Sign in failed';
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _role = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
