import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/delegate.dart';

class DelegatesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _ref(String clientId) => _firestore
      .collection('users')
      .doc(clientId)
      .collection('delegates');

  Future<List<Delegate>> getDelegates(String clientId) async {
    final snap = await _ref(clientId).orderBy('name').get();
    return snap.docs
        .map((d) => Delegate.fromFirestore(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> addDelegate(
    String clientId, {
    required String name,
    required String email,
  }) async {
    await _ref(clientId).add({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'addedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> removeDelegate(String clientId, String delegateId) async {
    await _ref(clientId).doc(delegateId).delete();
  }
}
