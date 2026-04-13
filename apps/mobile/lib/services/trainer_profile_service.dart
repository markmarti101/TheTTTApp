import 'package:cloud_firestore/cloud_firestore.dart';

class TrainerQualification {
  final String id;
  final String title;
  final String? issuer;
  final String expiryDate; // ISO date string YYYY-MM-DD

  TrainerQualification({
    required this.id,
    required this.title,
    this.issuer,
    required this.expiryDate,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        if (issuer != null) 'issuer': issuer,
        'expiryDate': expiryDate,
      };

  factory TrainerQualification.fromMap(Map<String, dynamic> map) {
    return TrainerQualification(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      issuer: map['issuer'] as String?,
      expiryDate: map['expiryDate'] as String? ?? '',
    );
  }
}

class TrainerRate {
  final String trainerId;
  final double? dayRate;
  final String? contractUrl;

  TrainerRate({
    required this.trainerId,
    this.dayRate,
    this.contractUrl,
  });
}

class TrainerProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Qualifications (trainer-owned, company-readable) ───────────────────────

  Future<List<TrainerQualification>> getQualifications(
      String trainerId) async {
    final doc = await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    final quals = data['qualifications'] as List<dynamic>?;
    if (quals == null) return [];
    return quals
        .whereType<Map<String, dynamic>>()
        .map(TrainerQualification.fromMap)
        .toList();
  }

  Future<void> addQualification(
      String trainerId, TrainerQualification qual) async {
    final existing = await getQualifications(trainerId);
    existing.add(qual);
    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .set({
      'qualifications': existing.map((q) => q.toMap()).toList(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteQualification(
      String trainerId, String qualId) async {
    final existing = await getQualifications(trainerId);
    existing.removeWhere((q) => q.id == qualId);
    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .set({
      'qualifications': existing.map((q) => q.toMap()).toList(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  // ── Company rates per trainer ──────────────────────────────────────────────

  Future<TrainerRate?> getTrainerRate(
      String companyId, String trainerId) async {
    final doc = await _firestore
        .collection('trainer_rates')
        .doc('${companyId}_$trainerId')
        .get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return TrainerRate(
      trainerId: trainerId,
      dayRate: (data['dayRate'] as num?)?.toDouble(),
      contractUrl: data['contractUrl'] as String?,
    );
  }

  Future<void> setTrainerRate(
    String companyId,
    String trainerId, {
    double? dayRate,
    String? contractUrl,
  }) async {
    await _firestore
        .collection('trainer_rates')
        .doc('${companyId}_$trainerId')
        .set({
      'companyId': companyId,
      'trainerId': trainerId,
      'dayRate': dayRate,
      'contractUrl': contractUrl,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
