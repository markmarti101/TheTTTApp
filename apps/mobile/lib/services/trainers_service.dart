import 'package:cloud_firestore/cloud_firestore.dart';

class TrainerOption {
  final String id;
  final String email;
  final String? displayName;

  TrainerOption({required this.id, required this.email, this.displayName});
}

class TrainersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<TrainerOption>> getTrainers(String trainingCompanyId) async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'freelance_trainer')
        .where('companyId', isEqualTo: trainingCompanyId)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return TrainerOption(
        id: d.id,
        email: data['email'] as String? ?? '',
        displayName: data['displayName'] as String?,
      );
    }).toList();
  }
}
