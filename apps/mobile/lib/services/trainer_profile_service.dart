import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

// ── Compliance models ─────────────────────────────────────────────────────────

class DBSRecord {
  final String? certificateNumber;
  final String? expiryDate; // YYYY-MM-DD
  DBSRecord({this.certificateNumber, this.expiryDate});

  Map<String, dynamic> toMap() => {
        if (certificateNumber != null) 'certificateNumber': certificateNumber,
        if (expiryDate != null) 'expiryDate': expiryDate,
      };

  factory DBSRecord.fromMap(Map<String, dynamic> m) => DBSRecord(
        certificateNumber: m['certificateNumber'] as String?,
        expiryDate: m['expiryDate'] as String?,
      );
}

class InsuranceRecord {
  final String? provider;
  final String? policyNumber;
  final String? expiryDate; // YYYY-MM-DD
  InsuranceRecord({this.provider, this.policyNumber, this.expiryDate});

  Map<String, dynamic> toMap() => {
        if (provider != null) 'provider': provider,
        if (policyNumber != null) 'policyNumber': policyNumber,
        if (expiryDate != null) 'expiryDate': expiryDate,
      };

  factory InsuranceRecord.fromMap(Map<String, dynamic> m) => InsuranceRecord(
        provider: m['provider'] as String?,
        policyNumber: m['policyNumber'] as String?,
        expiryDate: m['expiryDate'] as String?,
      );
}

class CPDEntry {
  final String id;
  final String title;
  final String? provider;
  final String completedDate; // YYYY-MM-DD
  final double? hours;

  CPDEntry({
    required this.id,
    required this.title,
    this.provider,
    required this.completedDate,
    this.hours,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        if (provider != null) 'provider': provider,
        'completedDate': completedDate,
        if (hours != null) 'hours': hours,
      };

  factory CPDEntry.fromMap(Map<String, dynamic> m) => CPDEntry(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        provider: m['provider'] as String?,
        completedDate: m['completedDate'] as String? ?? '',
        hours: (m['hours'] as num?)?.toDouble(),
      );
}

class ComplianceData {
  final DBSRecord? dbs;
  final InsuranceRecord? insurance;
  final List<CPDEntry> cpd;

  ComplianceData({this.dbs, this.insurance, List<CPDEntry>? cpd})
      : cpd = cpd ?? [];
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

class BankingDetails {
  final String? accountHolderName;
  final String? bankName;
  final String? accountNumber;
  final String? sortCode;

  BankingDetails({
    this.accountHolderName,
    this.bankName,
    this.accountNumber,
    this.sortCode,
  });

  bool get isEmpty =>
      (accountHolderName?.isEmpty ?? true) &&
      (bankName?.isEmpty ?? true) &&
      (accountNumber?.isEmpty ?? true) &&
      (sortCode?.isEmpty ?? true);

  Map<String, dynamic> toMap() => {
        if (accountHolderName != null) 'accountHolderName': accountHolderName,
        if (bankName != null) 'bankName': bankName,
        if (accountNumber != null) 'accountNumber': accountNumber,
        if (sortCode != null) 'sortCode': sortCode,
      };

  factory BankingDetails.fromMap(Map<String, dynamic> m) => BankingDetails(
        accountHolderName: m['accountHolderName'] as String?,
        bankName: m['bankName'] as String?,
        accountNumber: m['accountNumber'] as String?,
        sortCode: m['sortCode'] as String?,
      );
}

class CourseNote {
  final String id;
  final String text;
  final String createdAt;

  CourseNote({required this.id, required this.text, required this.createdAt});

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'createdAt': createdAt,
      };

  factory CourseNote.fromMap(Map<String, dynamic> m) => CourseNote(
        id: m['id'] as String? ?? '',
        text: m['text'] as String? ?? '',
        createdAt: m['createdAt'] as String? ?? '',
      );
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

  // ── Compliance documents ──────────────────────────────────────────────────

  Future<ComplianceData> getCompliance(String trainerId) async {
    try {
      final doc = await _firestore
          .collection('trainer_profiles')
          .doc(trainerId)
          .get();
      if (!doc.exists) return ComplianceData();
      final data = doc.data()!;
      final comp = data['compliance'] as Map<String, dynamic>?;
      if (comp == null) return ComplianceData();

      final dbsMap = comp['dbs'] as Map<String, dynamic>?;
      final insMap = comp['insurance'] as Map<String, dynamic>?;
      final cpdList = comp['cpd'] as List<dynamic>?;

      return ComplianceData(
        dbs: dbsMap != null ? DBSRecord.fromMap(dbsMap) : null,
        insurance: insMap != null ? InsuranceRecord.fromMap(insMap) : null,
        cpd: cpdList
                ?.whereType<Map<String, dynamic>>()
                .map(CPDEntry.fromMap)
                .toList() ??
            [],
      );
    } catch (e) {
      debugPrint('[TrainerProfileService] getCompliance failed: $e');
      return ComplianceData();
    }
  }

  /// Reads current compliance, replaces the requested field, writes the whole
  /// map back. This avoids any ambiguity around nested-path update behaviour
  /// and ensures no existing fields (dbs / insurance / cpd) are wiped.
  Future<void> _patchCompliance(
      String trainerId, String field, dynamic value) async {
    final current = await getCompliance(trainerId);
    final compMap = <String, dynamic>{
      'dbs': current.dbs?.toMap(),
      'insurance': current.insurance?.toMap(),
      'cpd': current.cpd.map((e) => e.toMap()).toList(),
      field: value, // overwrite only the target field
    };
    // Remove null entries (not-yet-set fields).
    compMap.removeWhere((_, v) => v == null);

    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .set({
      'compliance': compMap,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> setDBS(String trainerId, DBSRecord dbs) async {
    await _patchCompliance(trainerId, 'dbs', dbs.toMap());
  }

  Future<void> setInsurance(String trainerId, InsuranceRecord insurance) async {
    await _patchCompliance(trainerId, 'insurance', insurance.toMap());
  }

  Future<void> addCPDEntry(String trainerId, CPDEntry entry) async {
    final existing = (await getCompliance(trainerId)).cpd;
    existing.add(entry);
    await _patchCompliance(
        trainerId, 'cpd', existing.map((e) => e.toMap()).toList());
  }

  Future<void> deleteCPDEntry(String trainerId, String entryId) async {
    final existing = (await getCompliance(trainerId)).cpd;
    existing.removeWhere((e) => e.id == entryId);
    await _patchCompliance(
        trainerId, 'cpd', existing.map((e) => e.toMap()).toList());
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

  // ── Banking details (trainer-owned) ───────────────────────────────────────

  Future<BankingDetails> getBankingDetails(String trainerId) async {
    try {
      final doc = await _firestore
          .collection('trainer_profiles')
          .doc(trainerId)
          .collection('private')
          .doc('banking')
          .get();
      if (!doc.exists) return BankingDetails();
      final data = doc.data();
      if (data == null) return BankingDetails();
      return BankingDetails.fromMap(data);
    } catch (_) {
      return BankingDetails();
    }
  }

  Future<void> clearBankingDetails(String trainerId) async {
    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .collection('private')
        .doc('banking')
        .delete();
  }

  Future<void> setBankingDetails(
      String trainerId, BankingDetails details) async {
    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .collection('private')
        .doc('banking')
        .set({
      ...details.toMap(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ── Availability (trainer-owned) ──────────────────────────────────────────

  Future<Map<String, bool>> getAvailability(String trainerId) async {
    try {
      final doc = await _firestore
          .collection('trainer_profiles')
          .doc(trainerId)
          .get();
      if (!doc.exists) return {};
      final avail = doc.data()?['availability'] as Map<String, dynamic>?;
      if (avail == null) return {};
      return avail.map((k, v) => MapEntry(k, v as bool));
    } catch (_) {
      return {};
    }
  }

  Future<void> setAvailabilityDay(
      String trainerId, String dateStr, bool available) async {
    final current = await getAvailability(trainerId);
    current[dateStr] = available;
    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .set({
      'availability': current,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> clearAvailabilityDay(
      String trainerId, String dateStr) async {
    final current = await getAvailability(trainerId);
    current.remove(dateStr);
    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .set({
      'availability': current,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  // ── Course notes (trainer-owned, per course) ──────────────────────────────

  Future<List<CourseNote>> getCourseNotes(
      String trainerId, String courseId) async {
    try {
      final doc = await _firestore
          .collection('trainer_profiles')
          .doc(trainerId)
          .collection('course_notes')
          .doc(courseId)
          .get();
      if (!doc.exists) return [];
      final list = doc.data()?['notes'] as List<dynamic>?;
      if (list == null) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CourseNote.fromMap)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> addCourseNote(
      String trainerId, String courseId, String text) async {
    final existing = await getCourseNotes(trainerId, courseId);
    existing.insert(
      0,
      CourseNote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .collection('course_notes')
        .doc(courseId)
        .set({
      'notes': existing.map((n) => n.toMap()).toList(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteCourseNote(
      String trainerId, String courseId, String noteId) async {
    final existing = await getCourseNotes(trainerId, courseId);
    existing.removeWhere((n) => n.id == noteId);
    await _firestore
        .collection('trainer_profiles')
        .doc(trainerId)
        .collection('course_notes')
        .doc(courseId)
        .set({
      'notes': existing.map((n) => n.toMap()).toList(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
