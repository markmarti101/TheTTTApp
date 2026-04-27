import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';

class NotificationService {
  static const _col = 'notifications';
  final FirebaseFirestore _db;
  NotificationService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<void> send({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  }) async {
    await _db.collection(_col).add({
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'type': type,
      if (relatedId != null) 'relatedId': relatedId,
      'read': false,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<AppNotification>> getForUser(String userId) async {
    final snap = await _db
        .collection(_col)
        .where('recipientId', isEqualTo: userId)
        .get();
    final list = snap.docs
        .map((d) => AppNotification.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<int> getUnreadCount(String userId) async {
    final snap = await _db
        .collection(_col)
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    return snap.size;
  }

  Future<void> markRead(String notificationId) async {
    await _db.collection(_col).doc(notificationId).update({'read': true});
  }

  Future<void> markAllRead(String userId) async {
    final snap = await _db
        .collection(_col)
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> clearAll(String userId) async {
    final snap = await _db
        .collection(_col)
        .where('recipientId', isEqualTo: userId)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Looks up the ownerId of a training company — used to notify the company admin.
  Future<String?> getCompanyOwnerId(String trainingCompanyId) async {
    final doc = await _db
        .collection('training_companies')
        .doc(trainingCompanyId)
        .get();
    return doc.data()?['ownerId'] as String?;
  }
}
