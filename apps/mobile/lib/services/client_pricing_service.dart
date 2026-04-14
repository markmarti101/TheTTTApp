import 'package:cloud_firestore/cloud_firestore.dart';

class ClientPricing {
  final String clientId;
  final double? dayRate;
  final double? halfDayRate;
  final String? notes;

  ClientPricing({
    required this.clientId,
    this.dayRate,
    this.halfDayRate,
    this.notes,
  });
}

class ClientPricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ClientPricing?> getPricing(
      String companyId, String clientId) async {
    final doc = await _firestore
        .collection('client_pricing')
        .doc('${companyId}_$clientId')
        .get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return ClientPricing(
      clientId: clientId,
      dayRate: (data['dayRate'] as num?)?.toDouble(),
      halfDayRate: (data['halfDayRate'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
    );
  }

  Future<void> setPricing(
    String companyId,
    String clientId, {
    double? dayRate,
    double? halfDayRate,
    String? notes,
  }) async {
    await _firestore
        .collection('client_pricing')
        .doc('${companyId}_$clientId')
        .set({
      'companyId': companyId,
      'clientId': clientId,
      'dayRate': dayRate,
      'halfDayRate': halfDayRate,
      'notes': notes,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
