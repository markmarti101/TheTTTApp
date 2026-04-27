import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/course_request.dart';

void main() {
  group('CourseRequest.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'Leadership Training',
        'topic': 'Management',
        'preferredDates': ['2024-06-01', '2024-06-08'],
        'notes': 'Outdoor preferred',
        'status': 'pending',
        'declineReason': null,
        'createdAt': '2024-05-01T00:00:00.000Z',
        'updatedAt': '2024-05-01T00:00:00.000Z',
        'delegateCount': 12,
        'poNumber': 'PO-999',
        'venuePreference': 'Hotel',
        'venueSetup': 'theatre',
        'cateringNotes': 'Vegetarian only',
        'accessibilityNotes': 'Wheelchair access needed',
      };

      final req = CourseRequest.fromFirestore('req1', data);

      expect(req.id, 'req1');
      expect(req.trainingCompanyId, 'comp1');
      expect(req.clientId, 'client1');
      expect(req.title, 'Leadership Training');
      expect(req.topic, 'Management');
      expect(req.preferredDates, ['2024-06-01', '2024-06-08']);
      expect(req.notes, 'Outdoor preferred');
      expect(req.status, 'pending');
      expect(req.declineReason, isNull);
      expect(req.delegateCount, 12);
      expect(req.poNumber, 'PO-999');
      expect(req.venuePreference, 'Hotel');
      expect(req.venueSetup, 'theatre');
      expect(req.cateringNotes, 'Vegetarian only');
      expect(req.accessibilityNotes, 'Wheelchair access needed');
    });

    test('defaults status to pending when missing', () {
      final data = {
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'Test',
        'createdAt': '',
        'updatedAt': '',
      };
      final req = CourseRequest.fromFirestore('id', data);
      expect(req.status, 'pending');
    });

    test('handles null optional fields', () {
      final data = {
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'Test',
        'status': 'reviewed',
        'createdAt': '',
        'updatedAt': '',
      };
      final req = CourseRequest.fromFirestore('id', data);
      expect(req.topic, isNull);
      expect(req.preferredDates, isNull);
      expect(req.notes, isNull);
      expect(req.declineReason, isNull);
      expect(req.delegateCount, isNull);
      expect(req.poNumber, isNull);
      expect(req.venuePreference, isNull);
      expect(req.venueSetup, isNull);
      expect(req.cateringNotes, isNull);
      expect(req.accessibilityNotes, isNull);
    });

    test('parses delegateCount from num type', () {
      final data = {
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'Test',
        'delegateCount': 5.0, // comes as double from Firestore
        'createdAt': '',
        'updatedAt': '',
      };
      final req = CourseRequest.fromFirestore('id', data);
      expect(req.delegateCount, 5);
      expect(req.delegateCount, isA<int>());
    });

    test('parses preferredDates as list of strings', () {
      final data = {
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'Test',
        'preferredDates': ['2024-06-01'],
        'createdAt': '',
        'updatedAt': '',
      };
      final req = CourseRequest.fromFirestore('id', data);
      expect(req.preferredDates, hasLength(1));
      expect(req.preferredDates!.first, '2024-06-01');
    });

    test('parses declined status with reason', () {
      final data = {
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'Test',
        'status': 'declined',
        'declineReason': 'No availability',
        'createdAt': '',
        'updatedAt': '',
      };
      final req = CourseRequest.fromFirestore('id', data);
      expect(req.status, 'declined');
      expect(req.declineReason, 'No availability');
    });
  });
}
