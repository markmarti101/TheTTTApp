import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/venue.dart';

class VenuesService {
  final FirebaseFirestore _firestore;
  VenuesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<Venue>> getVenues(String trainingCompanyId) async {
    final snap = await _firestore
        .collection('venues')
        .where('trainingCompanyId', isEqualTo: trainingCompanyId)
        .orderBy('name', descending: false)
        .get();

    return snap.docs.map((d) => Venue.fromFirestore(d.id, d.data())).toList();
  }

  Future<void> deleteVenue(String venueId) async {
    await _firestore.collection('venues').doc(venueId).delete();
  }

  Future<void> updateVenue(
    String venueId, {
    required String name,
    required String address,
    int? capacity,
  }) async {
    await _firestore.collection('venues').doc(venueId).update({
      'name': name,
      'address': address,
      'capacity': capacity,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

