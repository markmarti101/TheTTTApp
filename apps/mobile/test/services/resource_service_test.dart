import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/resource.dart';
import 'package:training_triangle/services/resource_service.dart';

Resource _resource({
  String id = 'res1',
  String companyId = 'comp1',
  String name = 'Workbook',
  String category = 'book',
  int totalStock = 20,
  int reorderThreshold = 5,
  String unit = 'copies',
}) =>
    Resource(
      id: id,
      trainingCompanyId: companyId,
      name: name,
      category: category,
      totalStock: totalStock,
      reorderThreshold: reorderThreshold,
      unit: unit,
      createdAt: '2024-01-01T00:00:00.000Z',
      updatedAt: '2024-01-01T00:00:00.000Z',
    );

ResourceAllocation _allocation({
  String id = 'alloc1',
  String companyId = 'comp1',
  String resourceId = 'res1',
  String courseId = 'course1',
  String courseTitle = 'First Aid',
  int quantity = 5,
}) =>
    ResourceAllocation(
      id: id,
      trainingCompanyId: companyId,
      resourceId: resourceId,
      courseId: courseId,
      courseTitle: courseTitle,
      quantity: quantity,
      allocatedAt: '2024-06-01T00:00:00.000Z',
    );

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ResourceService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = ResourceService(firestore: fakeFirestore);
  });

  group('ResourceService.addResource', () {
    test('adds resource to Firestore', () async {
      await service.addResource(_resource());

      final snap = await fakeFirestore.collection('resources').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['name'], 'Workbook');
    });
  });

  group('ResourceService.getResources', () {
    test('returns resources for the given company sorted by name', () async {
      await service.addResource(_resource(name: 'Zapper', companyId: 'comp1'));
      await service.addResource(_resource(name: 'Alpha', companyId: 'comp1'));
      await service.addResource(_resource(name: 'Other', companyId: 'comp2'));

      final resources = await service.getResources('comp1');
      expect(resources.length, 2);
      expect(resources.first.name, 'Alpha');
      expect(resources.last.name, 'Zapper');
    });

    test('returns empty list when company has no resources', () async {
      final resources = await service.getResources('nobody');
      expect(resources, isEmpty);
    });
  });

  group('ResourceService.updateResource', () {
    test('updates resource fields', () async {
      await service.addResource(_resource(name: 'Old Name'));

      final snap = await fakeFirestore.collection('resources').get();
      final id = snap.docs.first.id;
      final updated = Resource(
        id: id,
        trainingCompanyId: 'comp1',
        name: 'New Name',
        category: 'equipment',
        totalStock: 10,
        reorderThreshold: 2,
        unit: 'units',
        createdAt: '',
        updatedAt: '',
      );

      await service.updateResource(updated);

      final doc =
          await fakeFirestore.collection('resources').doc(id).get();
      expect(doc.data()!['name'], 'New Name');
      expect(doc.data()!['category'], 'equipment');
      expect(doc.data()!['totalStock'], 10);
    });
  });

  group('ResourceService.deleteResource', () {
    test('removes resource and all its allocations', () async {
      await service.addResource(_resource());
      final snap = await fakeFirestore.collection('resources').get();
      final resourceId = snap.docs.first.id;

      // Add an allocation for this resource
      await fakeFirestore.collection('resource_allocations').add({
        'trainingCompanyId': 'comp1',
        'resourceId': resourceId,
        'courseId': 'course1',
        'courseTitle': 'First Aid',
        'quantity': 3,
        'allocatedAt': '',
      });

      await service.deleteResource(resourceId);

      final resourceDoc =
          await fakeFirestore.collection('resources').doc(resourceId).get();
      expect(resourceDoc.exists, isFalse);

      final allocSnap = await fakeFirestore
          .collection('resource_allocations')
          .where('resourceId', isEqualTo: resourceId)
          .get();
      expect(allocSnap.docs, isEmpty);
    });
  });

  group('ResourceService.getAllocations', () {
    test('returns allocations for the given company', () async {
      await service.addAllocation(_allocation(companyId: 'comp1'));
      await service.addAllocation(_allocation(companyId: 'comp2'));

      final allocations = await service.getAllocations('comp1');
      expect(allocations.length, 1);
      expect(allocations.first.trainingCompanyId, 'comp1');
    });
  });

  group('ResourceService.getAllocationsForResource', () {
    test('returns allocations for a specific resource sorted by date desc', () async {
      await fakeFirestore.collection('resource_allocations').add({
        'trainingCompanyId': 'comp1',
        'resourceId': 'res1',
        'courseId': 'c1',
        'courseTitle': 'T1',
        'quantity': 2,
        'allocatedAt': '2024-01-01T00:00:00.000Z',
      });
      await fakeFirestore.collection('resource_allocations').add({
        'trainingCompanyId': 'comp1',
        'resourceId': 'res1',
        'courseId': 'c2',
        'courseTitle': 'T2',
        'quantity': 3,
        'allocatedAt': '2024-02-01T00:00:00.000Z',
      });
      await fakeFirestore.collection('resource_allocations').add({
        'trainingCompanyId': 'comp1',
        'resourceId': 'res2',
        'courseId': 'c3',
        'courseTitle': 'T3',
        'quantity': 1,
        'allocatedAt': '2024-03-01T00:00:00.000Z',
      });

      final allocations = await service.getAllocationsForResource('res1');
      expect(allocations.length, 2);
      // sorted descending by allocatedAt
      expect(allocations.first.courseTitle, 'T2');
      expect(allocations.last.courseTitle, 'T1');
    });
  });

  group('ResourceService.addAllocation', () {
    test('adds allocation document', () async {
      await service.addAllocation(_allocation());

      final snap =
          await fakeFirestore.collection('resource_allocations').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['quantity'], 5);
    });
  });

  group('ResourceService.removeAllocation', () {
    test('deletes the allocation document', () async {
      final ref = await fakeFirestore.collection('resource_allocations').add({
        'trainingCompanyId': 'comp1',
        'resourceId': 'res1',
        'courseId': 'c1',
        'courseTitle': 'T',
        'quantity': 2,
        'allocatedAt': '',
      });

      await service.removeAllocation(ref.id);

      final doc = await fakeFirestore
          .collection('resource_allocations')
          .doc(ref.id)
          .get();
      expect(doc.exists, isFalse);
    });
  });
}
