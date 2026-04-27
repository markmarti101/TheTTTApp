import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invoice.dart';

class InvoiceService {
  final FirebaseFirestore _firestore;
  InvoiceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  static const _col = 'invoices';

  Future<String> createInvoice({
    required String courseId,
    required String courseTitle,
    required String clientId,
    required String trainingCompanyId,
    required double amount,
    required DateTime dueDate,
    String? poNumber,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final invoiceNumber = _generateNumber();
    final ref = await _firestore.collection(_col).add({
      'invoiceNumber': invoiceNumber,
      'courseId': courseId,
      'courseTitle': courseTitle,
      'clientId': clientId,
      'trainingCompanyId': trainingCompanyId,
      'amount': amount,
      'status': 'draft',
      'dueDate': dueDate.toUtc().toIso8601String(),
      'poNumber': poNumber,
      'notes': notes,
      'createdAt': now,
      'updatedAt': now,
    });
    return ref.id;
  }

  Future<List<Invoice>> getInvoicesByCompany(String companyId) async {
    final snap = await _firestore
        .collection(_col)
        .where('trainingCompanyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => Invoice.fromFirestore(d.id, d.data()))
        .toList();
  }

  Future<Invoice?> getInvoiceByCourse(String courseId) async {
    final snap = await _firestore
        .collection(_col)
        .where('courseId', isEqualTo: courseId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Invoice.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  }

  Future<Invoice?> getInvoice(String id) async {
    final doc = await _firestore.collection(_col).doc(id).get();
    if (!doc.exists) return null;
    return Invoice.fromFirestore(doc.id, doc.data()!);
  }

  Future<void> updateStatus(String id, String status) async {
    await _firestore.collection(_col).doc(id).update({
      'status': status,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteInvoice(String id) async {
    await _firestore.collection(_col).doc(id).delete();
  }

  String _generateNumber() {
    final now = DateTime.now();
    final ms = now.millisecondsSinceEpoch.toString().substring(7);
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'INV-${now.year}-$ms$rand';
  }
}
