import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/resource.dart';

class ResourceService {
  final FirebaseFirestore _db;
  ResourceService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ── Resources ────────────────────────────────────────────────────────────────

  Future<List<Resource>> getResources(String companyId) async {
    final snap = await _db
        .collection('resources')
        .where('trainingCompanyId', isEqualTo: companyId)
        .get();
    return snap.docs
        .map((d) => Resource.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> addResource(Resource resource) async {
    await _db.collection('resources').add(resource.toMap());
  }

  Future<void> updateResource(Resource resource) async {
    await _db.collection('resources').doc(resource.id).update({
      'name': resource.name,
      'category': resource.category,
      'totalStock': resource.totalStock,
      'reorderThreshold': resource.reorderThreshold,
      'unit': resource.unit,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteResource(String resourceId) async {
    // Remove all allocations for this resource first.
    final allocs = await _db
        .collection('resource_allocations')
        .where('resourceId', isEqualTo: resourceId)
        .get();
    final batch = _db.batch();
    for (final doc in allocs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('resources').doc(resourceId));
    await batch.commit();
  }

  // ── Allocations ──────────────────────────────────────────────────────────────

  Future<List<ResourceAllocation>> getAllocations(String companyId) async {
    final snap = await _db
        .collection('resource_allocations')
        .where('trainingCompanyId', isEqualTo: companyId)
        .get();
    return snap.docs
        .map((d) => ResourceAllocation.fromFirestore(d.id, d.data()))
        .toList();
  }

  Future<List<ResourceAllocation>> getAllocationsForResource(
      String resourceId) async {
    final snap = await _db
        .collection('resource_allocations')
        .where('resourceId', isEqualTo: resourceId)
        .get();
    return snap.docs
        .map((d) => ResourceAllocation.fromFirestore(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.allocatedAt.compareTo(a.allocatedAt));
  }

  Future<void> addAllocation(ResourceAllocation allocation) async {
    await _db.collection('resource_allocations').add(allocation.toMap());
  }

  Future<void> removeAllocation(String allocationId) async {
    await _db.collection('resource_allocations').doc(allocationId).delete();
  }
}
