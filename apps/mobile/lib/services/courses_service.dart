import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course.dart';

class CoursesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Course>> getCoursesByCompanyOrdered(
    String trainingCompanyId, {
    int limit = 200,
  }) async {
    final snap = await _firestore
        .collection('courses')
        .where('trainingCompanyId', isEqualTo: trainingCompanyId)
        .orderBy('startDate', descending: false)
        .limit(limit)
        .get();

    return snap.docs.map((d) => Course.fromFirestore(d.id, d.data())).toList();
  }

  Future<List<Course>> getCoursesByClient(String clientId) async {
    final snap = await _firestore
        .collection('courses')
        .where('clientId', isEqualTo: clientId)
        .get();
    final list = snap.docs
        .map((d) => Course.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  Future<Course?> getCourse(String courseId) async {
    final doc = await _firestore.collection('courses').doc(courseId).get();
    if (!doc.exists) return null;
    return Course.fromFirestore(doc.id, doc.data()!);
  }

  Future<void> updateCourseVenue(String courseId, String? venueId) async {
    await _firestore.collection('courses').doc(courseId).update({
      'venueId': venueId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> markCourseCompleted(String courseId) async {
    await _firestore.collection('courses').doc(courseId).update({
      'status': 'completed',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

