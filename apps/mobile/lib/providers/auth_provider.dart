import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/client_invites_service.dart';
import '../services/trainer_invites_service.dart';

typedef UserRole =
    String; // 'training_company' | 'freelance_trainer' | 'client'

class AuthProvider extends ChangeNotifier {
  ClientInvitesService? _invitesService;
  TrainerInvitesService? _trainerInvitesService;
  User? _user;
  UserRole? _role;
  String? _trainingCompanyId;
  bool _loading = true;
  String? _error;

  User? get user => _user;
  UserRole? get role => _role;
  String? get trainingCompanyId => _trainingCompanyId;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null && _role != null;

  AuthProvider({bool skipInit = false}) {
    if (!skipInit) {
      _invitesService = ClientInvitesService();
      _trainerInvitesService = TrainerInvitesService();
      _init();
    }
  }

  void _init() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      _user = user;
      _error = null;
      if (user != null) {
        _role = await _fetchRole(user.uid);
        if (_role == 'client') {
          await _claimClientInviteIfAny(user.uid, user.email);
        }
        if (_role == null) {
          await FirebaseAuth.instance.signOut();
          _user = null;
          _role = null;
          _trainingCompanyId = null;
        } else {
          _trainingCompanyId = await _fetchTrainingCompanyId(user.uid, _role);
        }
      } else {
        _role = null;
        _trainingCompanyId = null;
      }
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> _claimClientInviteIfAny(String uid, String? email) async {
    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail == null || normalizedEmail.isEmpty) return;
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userSnap = await userRef.get();
      final existing = userSnap.data();
      final alreadyLinked =
          (existing?['companyId'] as String?)?.isNotEmpty == true;
      if (alreadyLinked) return;

      final invite = await _invitesService!.claimInviteForEmail(
        uid: uid,
        email: normalizedEmail,
      );
      if (invite == null) return;

      final now = DateTime.now().toUtc().toIso8601String();
      await userRef.set({
        'role': 'client',
        'email': normalizedEmail,
        'displayName':
            (invite['displayName'] as String?) ?? existing?['displayName'],
        'organisation':
            (invite['organisation'] as String?) ?? existing?['organisation'],
        'companyId': invite['companyId'],
        'updatedAt': now,
        if (existing == null) 'createdAt': now,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Called when a trainer explicitly accepts a company invite.
  Future<void> acceptTrainerInvite(String inviteId, String companyId) async {
    final uid = _user?.uid;
    if (uid == null) return;
    await _trainerInvitesService!.acceptInvite(inviteId, uid);
    final now = DateTime.now().toUtc().toIso8601String();
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'companyId': companyId,
      'updatedAt': now,
    }, SetOptions(merge: true));
    _trainingCompanyId = companyId;
    notifyListeners();
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

  Future<String?> _fetchTrainingCompanyId(String uid, UserRole? role) async {
    if (role == 'training_company') {
      // 1. Fast path: user doc already stores companyId.
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final userCompanyId = userDoc.data()?['companyId'] as String?;
        if (userCompanyId != null && userCompanyId.isNotEmpty) {
          return userCompanyId;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Failed reading user doc companyId: $e');
      }

      // 2. Query training_companies where user is in admins array.
      try {
        final snap = await FirebaseFirestore.instance
            .collection('training_companies')
            .where('admins', arrayContains: uid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final companyId = snap.docs.first.id;
          // Cache on user doc for faster future lookups.
          FirebaseFirestore.instance.collection('users').doc(uid).set({
            'companyId': companyId,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }, SetOptions(merge: true)).catchError((_) {});
          return companyId;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Failed querying admins array: $e');
      }

      // 3. Fallback for older records that only have ownerId.
      try {
        final ownerSnap = await FirebaseFirestore.instance
            .collection('training_companies')
            .where('ownerId', isEqualTo: uid)
            .limit(1)
            .get();
        if (ownerSnap.docs.isNotEmpty) {
          final companyId = ownerSnap.docs.first.id;
          FirebaseFirestore.instance.collection('users').doc(uid).set({
            'companyId': companyId,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }, SetOptions(merge: true)).catchError((_) {});
          return companyId;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Failed querying ownerId: $e');
      }
    } else if (role == 'client' || role == 'freelance_trainer') {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final companyId = userDoc.data()?['companyId'] as String?;
        if (companyId != null && companyId.isNotEmpty) {
          return companyId;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Failed reading $role companyId: $e');
      }
    }
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
          'email': email.trim(),
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
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
    _trainingCompanyId = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @visibleForTesting
  void setErrorForTest(String message) {
    _error = message;
    notifyListeners();
  }

  /// Called when an existing client claims a pending invite.
  /// Writes companyId to their user doc and updates the provider state.
  Future<void> linkClientToCompany(String uid, String companyId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'companyId': companyId,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
      _trainingCompanyId = companyId;
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] linkClientToCompany failed: $e');
      rethrow;
    }
  }

  /// Call after creating a training company so the app picks up trainingCompanyId.
  /// Pass [knownCompanyId] when you have the new doc ID from the create call.
  Future<void> refreshTrainingCompanyId([String? knownCompanyId]) async {
    if (knownCompanyId != null && knownCompanyId.isNotEmpty) {
      _trainingCompanyId = knownCompanyId;
      notifyListeners();
      return;
    }
    final uid = _user?.uid;
    if (uid == null || _role == null) return;
    _trainingCompanyId = await _fetchTrainingCompanyId(uid, _role);
    notifyListeners();
  }
}
