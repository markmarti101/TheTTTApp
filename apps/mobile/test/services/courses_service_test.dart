import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/services/courses_service.dart';

Map<String, dynamic> _baseCourse({
  String trainingCompanyId = 'comp1',
  String clientId = 'client1',
  String trainerId = 'trainer1',
  String status = 'confirmed',
  String title = 'First Aid',
  String startDate = '2024-06-01T09:00:00.000Z',
}) =>
    {
      'courseNumber': 'TT-2024-001',
      'title': title,
      'topic': 'Health & Safety',
      'trainingCompanyId': trainingCompanyId,
      'clientId': clientId,
      'trainerId': trainerId,
      'startDate': startDate,
      'endDate': '2024-06-01T17:00:00.000Z',
      'status': status,
      'createdAt': '2024-05-01T00:00:00.000Z',
      'updatedAt': '2024-05-01T00:00:00.000Z',
    };

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late CoursesService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = CoursesService(firestore: fakeFirestore);
  });

  group('CoursesService.getCourse', () {
    test('returns course by id', () async {
      final ref =
          await fakeFirestore.collection('courses').add(_baseCourse());
      final course = await service.getCourse(ref.id);
      expect(course, isNotNull);
      expect(course!.title, 'First Aid');
    });

    test('returns null when course does not exist', () async {
      final course = await service.getCourse('nonexistent');
      expect(course, isNull);
    });
  });

  group('CoursesService.getCoursesByClient', () {
    test('returns courses for the given clientId', () async {
      await fakeFirestore
          .collection('courses')
          .add(_baseCourse(clientId: 'client1'));
      await fakeFirestore
          .collection('courses')
          .add(_baseCourse(clientId: 'client2'));

      final courses = await service.getCoursesByClient('client1');
      expect(courses.length, 1);
      expect(courses.first.clientId, 'client1');
    });

    test('returns empty list when client has no courses', () async {
      final courses = await service.getCoursesByClient('nobody');
      expect(courses, isEmpty);
    });
  });

  group('CoursesService.getCoursesByTrainer', () {
    test('returns courses assigned to a specific trainer', () async {
      await fakeFirestore
          .collection('courses')
          .add(_baseCourse(trainerId: 'trainer1'));
      await fakeFirestore
          .collection('courses')
          .add(_baseCourse(trainerId: 'trainer2'));

      final courses = await service.getCoursesByTrainer('trainer1');
      expect(courses.length, 1);
      expect(courses.first.trainerId, 'trainer1');
    });
  });

  group('CoursesService.acceptJob', () {
    test('sets status to confirmed', () async {
      final ref = await fakeFirestore
          .collection('courses')
          .add(_baseCourse(status: 'pending_trainer'));

      await service.acceptJob(ref.id);

      final course = await service.getCourse(ref.id);
      expect(course!.status, 'confirmed');
    });
  });

  group('CoursesService.declineJob', () {
    test('sets status to trainer_declined', () async {
      final ref = await fakeFirestore
          .collection('courses')
          .add(_baseCourse(status: 'pending_trainer'));

      await service.declineJob(ref.id);

      final course = await service.getCourse(ref.id);
      expect(course!.status, 'trainer_declined');
    });
  });

  group('CoursesService.markCourseCompleted', () {
    test('sets status to completed', () async {
      final ref = await fakeFirestore
          .collection('courses')
          .add(_baseCourse(status: 'confirmed'));

      await service.markCourseCompleted(ref.id);

      final course = await service.getCourse(ref.id);
      expect(course!.status, 'completed');
    });
  });

  group('CoursesService.updateCourseVenue', () {
    test('sets venueId on the course', () async {
      final ref =
          await fakeFirestore.collection('courses').add(_baseCourse());

      await service.updateCourseVenue(ref.id, 'venue1');

      final doc =
          await fakeFirestore.collection('courses').doc(ref.id).get();
      expect(doc.data()!['venueId'], 'venue1');
    });

    test('can clear venueId by setting to null', () async {
      final ref = await fakeFirestore
          .collection('courses')
          .add({..._baseCourse(), 'venueId': 'venue1'});

      await service.updateCourseVenue(ref.id, null);

      final doc =
          await fakeFirestore.collection('courses').doc(ref.id).get();
      expect(doc.data()!['venueId'], isNull);
    });
  });

  group('CoursesService.updatePoNumber', () {
    test('sets poNumber on the course', () async {
      final ref =
          await fakeFirestore.collection('courses').add(_baseCourse());

      await service.updatePoNumber(ref.id, 'PO-999');

      final doc =
          await fakeFirestore.collection('courses').doc(ref.id).get();
      expect(doc.data()!['poNumber'], 'PO-999');
    });
  });

  group('CoursesService.getCoursesByCompanyOrdered', () {
    test('returns courses for the given company', () async {
      await fakeFirestore.collection('courses').add(
          _baseCourse(trainingCompanyId: 'comp1', startDate: '2024-06-01T09:00:00.000Z'));
      await fakeFirestore.collection('courses').add(
          _baseCourse(trainingCompanyId: 'comp2', startDate: '2024-06-02T09:00:00.000Z'));

      final courses =
          await service.getCoursesByCompanyOrdered('comp1');
      expect(courses.length, 1);
      expect(courses.first.trainingCompanyId, 'comp1');
    });
  });
}
