import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/course.dart';

void main() {
  group('Course.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'courseNumber': 'TT-2024-001',
        'title': 'First Aid',
        'topic': 'Health & Safety',
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'trainerId': 'trainer1',
        'venueId': 'venue1',
        'startDate': '2024-06-01T09:00:00.000Z',
        'endDate': '2024-06-01T17:00:00.000Z',
        'status': 'confirmed',
        'delegateIds': ['d1', 'd2'],
        'notes': 'Bring ID',
        'poNumber': 'PO-123',
        'createdAt': '2024-05-01T00:00:00.000Z',
        'updatedAt': '2024-05-02T00:00:00.000Z',
      };

      final course = Course.fromFirestore('course1', data);

      expect(course.id, 'course1');
      expect(course.courseNumber, 'TT-2024-001');
      expect(course.title, 'First Aid');
      expect(course.topic, 'Health & Safety');
      expect(course.trainingCompanyId, 'comp1');
      expect(course.clientId, 'client1');
      expect(course.trainerId, 'trainer1');
      expect(course.venueId, 'venue1');
      expect(course.status, 'confirmed');
      expect(course.delegateIds, ['d1', 'd2']);
      expect(course.notes, 'Bring ID');
      expect(course.poNumber, 'PO-123');
      expect(course.startDate.year, 2024);
      expect(course.startDate.month, 6);
      expect(course.startDate.day, 1);
    });

    test('defaults missing optional fields to null', () {
      final data = {
        'title': 'Course',
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'trainerId': 'trainer1',
        'startDate': '2024-06-01T09:00:00.000Z',
        'endDate': '2024-06-01T17:00:00.000Z',
        'status': 'confirmed',
        'createdAt': '',
        'updatedAt': '',
      };
      final course = Course.fromFirestore('id', data);
      expect(course.topic, isNull);
      expect(course.venueId, isNull);
      expect(course.delegateIds, isNull);
      expect(course.notes, isNull);
      expect(course.poNumber, isNull);
    });

    test('defaults status to pending_trainer when missing', () {
      final data = {
        'trainingCompanyId': 'c',
        'clientId': 'cl',
        'trainerId': 't',
        'startDate': '2024-01-01T09:00:00.000Z',
        'endDate': '2024-01-01T17:00:00.000Z',
        'createdAt': '',
        'updatedAt': '',
      };
      final course = Course.fromFirestore('id', data);
      expect(course.status, 'pending_trainer');
    });

    test('defaults courseNumber to empty string when missing', () {
      final data = {
        'trainingCompanyId': 'c',
        'clientId': 'cl',
        'trainerId': 't',
        'startDate': '2024-01-01T09:00:00.000Z',
        'endDate': '2024-01-01T17:00:00.000Z',
        'createdAt': '',
        'updatedAt': '',
      };
      final course = Course.fromFirestore('id', data);
      expect(course.courseNumber, '');
    });

    test('handles invalid date string gracefully', () {
      final data = {
        'trainingCompanyId': 'c',
        'clientId': 'cl',
        'trainerId': 't',
        'startDate': 'not-a-date',
        'endDate': 'also-bad',
        'createdAt': '',
        'updatedAt': '',
      };
      final course = Course.fromFirestore('id', data);
      expect(course.startDate.millisecondsSinceEpoch, 0);
    });

    test('handles null startDate gracefully', () {
      final data = {
        'trainingCompanyId': 'c',
        'clientId': 'cl',
        'trainerId': 't',
        'startDate': null,
        'endDate': null,
        'createdAt': '',
        'updatedAt': '',
      };
      final course = Course.fromFirestore('id', data);
      expect(course.startDate.millisecondsSinceEpoch, 0);
    });

    test('parses delegateIds list of mixed types as strings', () {
      final data = {
        'trainingCompanyId': 'c',
        'clientId': 'cl',
        'trainerId': 't',
        'startDate': '2024-01-01T09:00:00.000Z',
        'endDate': '2024-01-01T17:00:00.000Z',
        'delegateIds': ['del1', 'del2', 'del3'],
        'createdAt': '',
        'updatedAt': '',
      };
      final course = Course.fromFirestore('id', data);
      expect(course.delegateIds, hasLength(3));
      expect(course.delegateIds!.first, 'del1');
    });

    test('handles empty string fields', () {
      final data = {
        'courseNumber': '',
        'title': '',
        'trainingCompanyId': '',
        'clientId': '',
        'trainerId': '',
        'startDate': '2024-01-01T09:00:00.000Z',
        'endDate': '2024-01-01T17:00:00.000Z',
        'status': '',
        'createdAt': '',
        'updatedAt': '',
      };
      final course = Course.fromFirestore('id', data);
      expect(course.title, '');
      expect(course.courseNumber, '');
    });
  });
}
