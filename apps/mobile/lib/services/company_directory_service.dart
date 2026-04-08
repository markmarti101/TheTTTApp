import 'package:cloud_firestore/cloud_firestore.dart';

class UserSummary {
  final String id;
  final String email;
  final String? displayName;
  final String role;
  /// 'active' for linked users, 'pending' for unclaimed invites
  final String? status;

  UserSummary({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
    this.status = 'active',
  });
}

class CompanyDirectoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UserSummary>> _getUsersByRole({
    required String trainingCompanyId,
    required String role,
  }) async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .where('companyId', isEqualTo: trainingCompanyId)
        .get();

    return snap.docs
        .map(
          (d) => UserSummary(
            id: d.id,
            email: (d.data()['email'] as String?) ?? '',
            displayName: d.data()['displayName'] as String?,
            role: role,
          ),
        )
        .toList();
  }

  Future<List<UserSummary>> getClients(String trainingCompanyId) async {
    final clients = await _getUsersByRole(
      trainingCompanyId: trainingCompanyId,
      role: 'client',
    );

    // Fetch all courses for the company to determine which clients are active
    final coursesSnap = await _firestore
        .collection('courses')
        .where('trainingCompanyId', isEqualTo: trainingCompanyId)
        .get();

    final clientsWithCourses = coursesSnap.docs
        .map((d) => d.data()['clientId'] as String?)
        .whereType<String>()
        .toSet();

    return clients
        .map((c) => UserSummary(
              id: c.id,
              email: c.email,
              displayName: c.displayName,
              role: c.role,
              status: clientsWithCourses.contains(c.id) ? 'active' : 'pending',
            ))
        .toList();
  }

  Future<List<UserSummary>> getTrainers(String trainingCompanyId) {
    return _getUsersByRole(
      trainingCompanyId: trainingCompanyId,
      role: 'freelance_trainer',
    );
  }
}

