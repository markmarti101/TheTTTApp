import 'package:cloud_firestore/cloud_firestore.dart';

class ClientInvitesService {
  static const _invites = 'client_invites';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> createOrUpdateInvite({
    required String email,
    required String displayName,
    required String companyId,
    required String createdByUid,
    String? organisation,
    String? companyName,
  }) async {
    final normalized = normalizeEmail(email);
    final now = DateTime.now().toUtc().toIso8601String();

    final existing = await _firestore
        .collection(_invites)
        .where('email', isEqualTo: normalized)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    final data = <String, dynamic>{
      'email': normalized,
      'displayName': displayName.trim(),
      'companyId': companyId,
      if (companyName != null && companyName.trim().isNotEmpty)
        'companyName': companyName.trim(),
      if (organisation != null && organisation.trim().isNotEmpty)
        'organisation': organisation.trim(),
      'status': 'pending',
      'createdBy': createdByUid,
      'updatedAt': now,
    };

    if (existing.docs.isNotEmpty) {
      await _firestore
          .collection(_invites)
          .doc(existing.docs.first.id)
          .update(data);
      return;
    }

    await _firestore.collection(_invites).add({...data, 'createdAt': now});
  }

  Future<Map<String, dynamic>?> claimInviteForEmail({
    required String uid,
    required String email,
  }) async {
    final normalized = normalizeEmail(email);
    final snap = await _firestore
        .collection(_invites)
        .where('email', isEqualTo: normalized)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final data = doc.data();
    final now = DateTime.now().toUtc().toIso8601String();

    await _firestore.collection(_invites).doc(doc.id).update({
      'status': 'claimed',
      'claimedByUid': uid,
      'claimedAt': now,
      'updatedAt': now,
    });

    return data;
  }
}
