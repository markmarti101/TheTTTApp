import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/course.dart';

class TrainerReport {
  final String trainerId;
  final String trainerName;
  final int totalCourses;
  final int completedCourses;
  final int upcomingCourses;
  final int totalDelegates;

  TrainerReport({
    required this.trainerId,
    required this.trainerName,
    required this.totalCourses,
    required this.completedCourses,
    required this.upcomingCourses,
    required this.totalDelegates,
  });
}

class ClientReport {
  final String clientId;
  final String clientName;
  final int totalCourses;
  final int completedCourses;
  final int upcomingCourses;
  final int totalDelegates;

  ClientReport({
    required this.clientId,
    required this.clientName,
    required this.totalCourses,
    required this.completedCourses,
    required this.upcomingCourses,
    required this.totalDelegates,
  });
}

class CompanySummary {
  final int totalCourses;
  final int completedCourses;
  final int upcomingCourses;
  final int cancelledCourses;
  final int totalDelegates;

  CompanySummary({
    required this.totalCourses,
    required this.completedCourses,
    required this.upcomingCourses,
    required this.cancelledCourses,
    required this.totalDelegates,
  });
}

class ReportsService {
  final _firestore = FirebaseFirestore.instance;

  Future<List<Course>> _fetchCourses(
    String companyId,
    DateTime? from,
    DateTime? to,
  ) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('courses')
        .where('trainingCompanyId', isEqualTo: companyId);

    if (from != null) {
      query = query.where(
        'startDate',
        isGreaterThanOrEqualTo: from.toUtc().toIso8601String(),
      );
    }
    if (to != null) {
      query = query.where(
        'startDate',
        isLessThanOrEqualTo: to.toUtc().toIso8601String(),
      );
    }

    final snap = await query.get();
    return snap.docs.map((d) => Course.fromFirestore(d.id, d.data())).toList();
  }

  Future<String> _resolveUserName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final name = (data['displayName'] as String?)?.trim();
        if (name != null && name.isNotEmpty) return name;
        final email = (data['email'] as String?)?.trim();
        if (email != null && email.isNotEmpty) return email;
      }
    } catch (_) {}
    return userId;
  }

  Future<Map<String, String>> _resolveNames(Set<String> ids) async {
    final results = await Future.wait(ids.map((id) async {
      final name = await _resolveUserName(id);
      return MapEntry(id, name);
    }));
    return Map.fromEntries(results);
  }

  Future<CompanySummary> getCompanySummary(
    String companyId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final courses = await _fetchCourses(companyId, from, to);
    final now = DateTime.now();
    int completed = 0, upcoming = 0, cancelled = 0, delegates = 0;
    for (final c in courses) {
      final s = c.status.toLowerCase();
      if (s == 'completed') {
        completed++;
      } else if (s == 'trainer_declined' || s == 'declined') {
        cancelled++;
      } else if (c.startDate.isAfter(now)) {
        upcoming++;
      }
      delegates += c.delegateIds?.length ?? 0;
    }
    return CompanySummary(
      totalCourses: courses.length,
      completedCourses: completed,
      upcomingCourses: upcoming,
      cancelledCourses: cancelled,
      totalDelegates: delegates,
    );
  }

  Future<List<TrainerReport>> getPerTrainerReport(
    String companyId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final courses = await _fetchCourses(companyId, from, to);
    final now = DateTime.now();

    final grouped = <String, List<Course>>{};
    for (final c in courses) {
      grouped.putIfAbsent(c.trainerId, () => []).add(c);
    }

    final names = await _resolveNames(grouped.keys.toSet());

    return grouped.entries.map((e) {
      final trainerCourses = e.value;
      int completed = 0, upcoming = 0, delegates = 0;
      for (final c in trainerCourses) {
        if (c.status.toLowerCase() == 'completed') completed++;
        if (c.startDate.isAfter(now)) upcoming++;
        delegates += c.delegateIds?.length ?? 0;
      }
      return TrainerReport(
        trainerId: e.key,
        trainerName: names[e.key] ?? e.key,
        totalCourses: trainerCourses.length,
        completedCourses: completed,
        upcomingCourses: upcoming,
        totalDelegates: delegates,
      );
    }).toList()
      ..sort((a, b) => b.totalCourses.compareTo(a.totalCourses));
  }

  Future<List<ClientReport>> getPerClientReport(
    String companyId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final courses = await _fetchCourses(companyId, from, to);
    final now = DateTime.now();

    final grouped = <String, List<Course>>{};
    for (final c in courses) {
      grouped.putIfAbsent(c.clientId, () => []).add(c);
    }

    final names = await _resolveNames(grouped.keys.toSet());

    return grouped.entries.map((e) {
      final clientCourses = e.value;
      int completed = 0, upcoming = 0, delegates = 0;
      for (final c in clientCourses) {
        if (c.status.toLowerCase() == 'completed') completed++;
        if (c.startDate.isAfter(now)) upcoming++;
        delegates += c.delegateIds?.length ?? 0;
      }
      return ClientReport(
        clientId: e.key,
        clientName: names[e.key] ?? e.key,
        totalCourses: clientCourses.length,
        completedCourses: completed,
        upcomingCourses: upcoming,
        totalDelegates: delegates,
      );
    }).toList()
      ..sort((a, b) => b.totalCourses.compareTo(a.totalCourses));
  }

  String buildCsvTrainers(List<TrainerReport> rows) {
    final lines = <String>[
      'Trainer,Total Courses,Completed,Upcoming,Total Delegates',
    ];
    for (final r in rows) {
      lines.add(
        '"${r.trainerName}",${r.totalCourses},${r.completedCourses},'
        '${r.upcomingCourses},${r.totalDelegates}',
      );
    }
    return lines.join('\n');
  }

  String buildCsvClients(List<ClientReport> rows) {
    final lines = <String>[
      'Client,Total Courses,Completed,Upcoming,Total Delegates',
    ];
    for (final r in rows) {
      lines.add(
        '"${r.clientName}",${r.totalCourses},${r.completedCourses},'
        '${r.upcomingCourses},${r.totalDelegates}',
      );
    }
    return lines.join('\n');
  }
}
