import 'package:cloud_firestore/cloud_firestore.dart';

class AuditEntry {
  final String id;
  final String companyId;
  final String action;
  final String description;
  final String performedBy;
  final String? entityId;
  final String createdAt;

  AuditEntry({
    required this.id,
    required this.companyId,
    required this.action,
    required this.description,
    required this.performedBy,
    this.entityId,
    required this.createdAt,
  });

  factory AuditEntry.fromFirestore(String id, Map<String, dynamic> d) =>
      AuditEntry(
        id: id,
        companyId: d['companyId'] as String? ?? '',
        action: d['action'] as String? ?? '',
        description: d['description'] as String? ?? '',
        performedBy: d['performedBy'] as String? ?? '',
        entityId: d['entityId'] as String?,
        createdAt: d['createdAt'] as String? ?? '',
      );
}

class AuditLogService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> log({
    required String companyId,
    required String action,
    required String description,
    required String performedBy,
    String? entityId,
  }) async {
    try {
      await _firestore.collection('audit_log').add({
        'companyId': companyId,
        'action': action,
        'description': description,
        'performedBy': performedBy,
        if (entityId != null) 'entityId': entityId,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<List<AuditEntry>> getEntries(String companyId) async {
    final snap = await _firestore
        .collection('audit_log')
        .where('companyId', isEqualTo: companyId)
        .get();
    final entries = snap.docs
        .map((d) => AuditEntry.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries.take(200).toList();
  }
}
