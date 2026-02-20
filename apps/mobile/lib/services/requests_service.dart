import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_request.dart';

class RequestsService {
  static const _requests = 'course_requests';
  static const _courses = 'courses';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<CourseRequest>> getRequestsByCompany(String trainingCompanyId) async {
    final snap = await _firestore
        .collection(_requests)
        .where('trainingCompanyId', isEqualTo: trainingCompanyId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((d) => CourseRequest.fromFirestore(d.id, d.data()))
        .toList();
  }

  Future<CourseRequest?> getRequest(String id) async {
    final doc = await _firestore.collection(_requests).doc(id).get();
    if (!doc.exists) return null;
    return CourseRequest.fromFirestore(doc.id, doc.data()!);
  }

  Future<void> markRequestReviewed(String id) async {
    final req = await getRequest(id);
    if (req?.status == 'pending') {
      await _firestore.collection(_requests).doc(id).update({
        'status': 'reviewed',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<void> declineRequest(String id, String reason) async {
    await _firestore.collection(_requests).doc(id).update({
      'status': 'declined',
      'declineReason': reason,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<String> approveRequest(
    String requestId,
    String trainerId,
    DateTime scheduledAt,
  ) async {
    final req = await getRequest(requestId);
    if (req == null) throw Exception('Request not found');
    if (req.status != 'pending' && req.status != 'reviewed') {
      throw Exception('Request already processed');
    }

    final courseNumber =
        'TT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(6).toUpperCase()}';
    final endDate = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day, 17, 0, 0);

    final courseRef = await _firestore.collection(_courses).add({
      'courseNumber': courseNumber,
      'title': req.title,
      'topic': req.topic ?? '',
      'trainingCompanyId': req.trainingCompanyId,
      'clientId': req.clientId,
      'trainerId': trainerId,
      'startDate': scheduledAt.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      'status': 'pending_trainer',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });

    await _firestore.collection(_requests).doc(requestId).update({
      'status': 'approved',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });

    return courseRef.id;
  }
}
