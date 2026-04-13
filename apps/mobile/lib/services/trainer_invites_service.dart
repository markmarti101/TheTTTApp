import 'package:cloud_firestore/cloud_firestore.dart';

class TrainerInvitesService {
  static const _invites = 'trainer_invites';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String normalizeEmail(String email) => email.trim().toLowerCase();

  Future<void> createOrUpdateInvite({
    required String email,
    required String displayName,
    required String companyId,
    required String createdByUid,
    String? companyName,
    String? specialty,
  }) async {
    final normalized = normalizeEmail(email);
    final now = DateTime.now().toUtc().toIso8601String();

    final existing = await _firestore
        .collection(_invites)
        .where('email', isEqualTo: normalized)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    final data = <String, dynamic>{
      'email': normalized,
      'displayName': displayName.trim(),
      'companyId': companyId,
      if (companyName != null && companyName.trim().isNotEmpty)
        'companyName': companyName.trim(),
      if (specialty != null && specialty.trim().isNotEmpty)
        'specialty': specialty.trim(),
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

  /// Returns all pending company invites for the given email address.
  Future<List<Map<String, dynamic>>> getPendingInvitesForEmail(
      String email) async {
    final normalized = normalizeEmail(email);
    final snap = await _firestore
        .collection(_invites)
        .where('email', isEqualTo: normalized)
        .where('status', isEqualTo: 'pending')
        .get();

    return snap.docs
        .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
        .toList();
  }

  /// Trainer explicitly accepts an invite by its document ID.
  Future<void> acceptInvite(String inviteId, String uid) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _firestore.collection(_invites).doc(inviteId).update({
      'status': 'claimed',
      'claimedByUid': uid,
      'claimedAt': now,
      'updatedAt': now,
    });
  }

  /// Trainer explicitly declines an invite.
  Future<void> declineInvite(String inviteId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _firestore.collection(_invites).doc(inviteId).update({
      'status': 'declined',
      'updatedAt': now,
    });
  }
}
