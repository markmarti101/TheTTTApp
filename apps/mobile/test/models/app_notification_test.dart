import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/app_notification.dart';

void main() {
  group('AppNotification.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'recipientId': 'user1',
        'title': 'Course Assigned',
        'body': 'You have been assigned to First Aid.',
        'type': 'course_assigned',
        'relatedId': 'course1',
        'read': false,
        'createdAt': '2024-06-01T10:00:00.000Z',
      };

      final notif = AppNotification.fromFirestore('notif1', data);

      expect(notif.id, 'notif1');
      expect(notif.recipientId, 'user1');
      expect(notif.title, 'Course Assigned');
      expect(notif.body, 'You have been assigned to First Aid.');
      expect(notif.type, 'course_assigned');
      expect(notif.relatedId, 'course1');
      expect(notif.read, isFalse);
      expect(notif.createdAt, '2024-06-01T10:00:00.000Z');
    });

    test('defaults read to false when missing', () {
      final notif = AppNotification.fromFirestore('id', {});
      expect(notif.read, isFalse);
    });

    test('parses read as true correctly', () {
      final notif = AppNotification.fromFirestore('id', {'read': true});
      expect(notif.read, isTrue);
    });

    test('defaults relatedId to null when missing', () {
      final notif = AppNotification.fromFirestore('id', {});
      expect(notif.relatedId, isNull);
    });

    test('relatedId is null when explicitly null in data', () {
      final data = {'relatedId': null};
      final notif = AppNotification.fromFirestore('id', data);
      expect(notif.relatedId, isNull);
    });

    test('defaults string fields to empty string when missing', () {
      final notif = AppNotification.fromFirestore('id', {});
      expect(notif.recipientId, '');
      expect(notif.title, '');
      expect(notif.body, '');
      expect(notif.type, '');
      expect(notif.createdAt, '');
    });

    test('parses all notification types', () {
      for (final type in [
        'course_assigned',
        'request_submitted',
        'request_approved',
        'request_declined',
        'course_confirmed',
      ]) {
        final notif = AppNotification.fromFirestore('id', {'type': type});
        expect(notif.type, type);
      }
    });
  });
}
