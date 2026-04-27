import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/delegate.dart';

void main() {
  group('Delegate.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'accessibilityNeeds': 'Wheelchair access',
        'dietaryRequirements': 'Vegan',
        'addedAt': '2024-05-01T10:00:00.000Z',
      };

      final delegate = Delegate.fromFirestore('del1', data);

      expect(delegate.id, 'del1');
      expect(delegate.name, 'Jane Doe');
      expect(delegate.email, 'jane@example.com');
      expect(delegate.accessibilityNeeds, 'Wheelchair access');
      expect(delegate.dietaryRequirements, 'Vegan');
      expect(delegate.addedAt, '2024-05-01T10:00:00.000Z');
    });

    test('handles missing optional fields as null', () {
      final data = {
        'name': 'John Smith',
        'email': 'john@example.com',
        'addedAt': '',
      };
      final delegate = Delegate.fromFirestore('id', data);
      expect(delegate.accessibilityNeeds, isNull);
      expect(delegate.dietaryRequirements, isNull);
    });

    test('defaults name and email to empty string when missing', () {
      final delegate = Delegate.fromFirestore('id', {'addedAt': ''});
      expect(delegate.name, '');
      expect(delegate.email, '');
    });
  });

  group('Delegate.hasAccessibility', () {
    test('returns true when accessibilityNeeds is non-empty', () {
      final delegate = Delegate(
        id: '1',
        name: 'Test',
        email: 'test@test.com',
        accessibilityNeeds: 'Ramp needed',
        addedAt: '',
      );
      expect(delegate.hasAccessibility, isTrue);
    });

    test('returns false when accessibilityNeeds is null', () {
      final delegate = Delegate(
        id: '1',
        name: 'Test',
        email: 'test@test.com',
        addedAt: '',
      );
      expect(delegate.hasAccessibility, isFalse);
    });

    test('returns false when accessibilityNeeds is whitespace only', () {
      final delegate = Delegate(
        id: '1',
        name: 'Test',
        email: 'test@test.com',
        accessibilityNeeds: '   ',
        addedAt: '',
      );
      expect(delegate.hasAccessibility, isFalse);
    });
  });

  group('Delegate.hasDietary', () {
    test('returns true when dietaryRequirements is non-empty', () {
      final delegate = Delegate(
        id: '1',
        name: 'Test',
        email: 'test@test.com',
        dietaryRequirements: 'Halal',
        addedAt: '',
      );
      expect(delegate.hasDietary, isTrue);
    });

    test('returns false when dietaryRequirements is null', () {
      final delegate = Delegate(
        id: '1',
        name: 'Test',
        email: 'test@test.com',
        addedAt: '',
      );
      expect(delegate.hasDietary, isFalse);
    });

    test('returns false when dietaryRequirements is whitespace only', () {
      final delegate = Delegate(
        id: '1',
        name: 'Test',
        email: 'test@test.com',
        dietaryRequirements: '  ',
        addedAt: '',
      );
      expect(delegate.hasDietary, isFalse);
    });
  });
}
