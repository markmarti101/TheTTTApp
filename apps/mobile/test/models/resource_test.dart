import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/resource.dart';

void main() {
  group('Resource.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'trainingCompanyId': 'comp1',
        'name': 'First Aid Manual',
        'category': 'book',
        'totalStock': 20,
        'reorderThreshold': 5,
        'unit': 'copies',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
      };

      final resource = Resource.fromFirestore('res1', data);

      expect(resource.id, 'res1');
      expect(resource.trainingCompanyId, 'comp1');
      expect(resource.name, 'First Aid Manual');
      expect(resource.category, 'book');
      expect(resource.totalStock, 20);
      expect(resource.reorderThreshold, 5);
      expect(resource.unit, 'copies');
      expect(resource.createdAt, '2024-01-01T00:00:00.000Z');
    });

    test('defaults category to other when missing', () {
      final resource = Resource.fromFirestore('id', {});
      expect(resource.category, 'other');
    });

    test('defaults unit to units when missing', () {
      final resource = Resource.fromFirestore('id', {});
      expect(resource.unit, 'units');
    });

    test('defaults totalStock and reorderThreshold to 0 when missing', () {
      final resource = Resource.fromFirestore('id', {});
      expect(resource.totalStock, 0);
      expect(resource.reorderThreshold, 0);
    });

    test('parses totalStock from double type', () {
      final data = {'totalStock': 10.0, 'reorderThreshold': 2.0};
      final resource = Resource.fromFirestore('id', data);
      expect(resource.totalStock, 10);
      expect(resource.totalStock, isA<int>());
      expect(resource.reorderThreshold, 2);
      expect(resource.reorderThreshold, isA<int>());
    });

    test('defaults name to empty string when missing', () {
      final resource = Resource.fromFirestore('id', {});
      expect(resource.name, '');
    });
  });

  group('Resource.toMap', () {
    test('returns correct map with all fields', () {
      final resource = Resource(
        id: 'res1',
        trainingCompanyId: 'comp1',
        name: 'Workbook',
        category: 'book',
        totalStock: 15,
        reorderThreshold: 3,
        unit: 'copies',
        createdAt: '2024-01-01T00:00:00.000Z',
        updatedAt: '2024-01-02T00:00:00.000Z',
      );

      final map = resource.toMap();

      expect(map['trainingCompanyId'], 'comp1');
      expect(map['name'], 'Workbook');
      expect(map['category'], 'book');
      expect(map['totalStock'], 15);
      expect(map['reorderThreshold'], 3);
      expect(map['unit'], 'copies');
      expect(map['createdAt'], '2024-01-01T00:00:00.000Z');
      expect(map['updatedAt'], '2024-01-02T00:00:00.000Z');
    });

    test('toMap does not include id field', () {
      final resource = Resource(
        id: 'res1',
        trainingCompanyId: 'comp1',
        name: 'Item',
        category: 'equipment',
        totalStock: 5,
        reorderThreshold: 1,
        unit: 'units',
        createdAt: '',
        updatedAt: '',
      );
      expect(resource.toMap().containsKey('id'), isFalse);
    });
  });

  group('ResourceAllocation.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'trainingCompanyId': 'comp1',
        'resourceId': 'res1',
        'courseId': 'course1',
        'courseTitle': 'First Aid',
        'quantity': 5,
        'allocatedAt': '2024-06-01T00:00:00.000Z',
      };

      final allocation = ResourceAllocation.fromFirestore('alloc1', data);

      expect(allocation.id, 'alloc1');
      expect(allocation.trainingCompanyId, 'comp1');
      expect(allocation.resourceId, 'res1');
      expect(allocation.courseId, 'course1');
      expect(allocation.courseTitle, 'First Aid');
      expect(allocation.quantity, 5);
      expect(allocation.allocatedAt, '2024-06-01T00:00:00.000Z');
    });

    test('defaults quantity to 0 when missing', () {
      final allocation = ResourceAllocation.fromFirestore('id', {});
      expect(allocation.quantity, 0);
    });

    test('parses quantity from double type', () {
      final data = {'quantity': 3.0};
      final allocation = ResourceAllocation.fromFirestore('id', data);
      expect(allocation.quantity, 3);
      expect(allocation.quantity, isA<int>());
    });

    test('defaults string fields to empty string when missing', () {
      final allocation = ResourceAllocation.fromFirestore('id', {});
      expect(allocation.trainingCompanyId, '');
      expect(allocation.resourceId, '');
      expect(allocation.courseId, '');
      expect(allocation.courseTitle, '');
      expect(allocation.allocatedAt, '');
    });
  });

  group('ResourceAllocation.toMap', () {
    test('returns correct map', () {
      final allocation = ResourceAllocation(
        id: 'alloc1',
        trainingCompanyId: 'comp1',
        resourceId: 'res1',
        courseId: 'course1',
        courseTitle: 'First Aid',
        quantity: 5,
        allocatedAt: '2024-06-01T00:00:00.000Z',
      );

      final map = allocation.toMap();

      expect(map['trainingCompanyId'], 'comp1');
      expect(map['resourceId'], 'res1');
      expect(map['courseId'], 'course1');
      expect(map['courseTitle'], 'First Aid');
      expect(map['quantity'], 5);
      expect(map['allocatedAt'], '2024-06-01T00:00:00.000Z');
    });

    test('toMap does not include id field', () {
      final allocation = ResourceAllocation(
        id: 'alloc1',
        trainingCompanyId: 'comp1',
        resourceId: 'res1',
        courseId: 'course1',
        courseTitle: 'T',
        quantity: 1,
        allocatedAt: '',
      );
      expect(allocation.toMap().containsKey('id'), isFalse);
    });
  });
}
