import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/services/notification_service.dart';
import 'package:training_triangle/services/requests_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late RequestsService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final notifs = NotificationService(firestore: fakeFirestore);
    service = RequestsService(firestore: fakeFirestore, notifs: notifs);
  });

  Future<void> seedCompany(String id, String ownerId) async {
    await fakeFirestore
        .collection('training_companies')
        .doc(id)
        .set({'ownerId': ownerId});
  }

  group('RequestsService.createRequest', () {
    test('creates a pending request', () async {
      await seedCompany('comp1', 'owner1');

      await service.createRequest(
        trainingCompanyId: 'comp1',
        clientId: 'client1',
        title: 'Leadership Training',
      );

      final snap = await fakeFirestore.collection('course_requests').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['title'], 'Leadership Training');
      expect(data['status'], 'pending');
      expect(data['clientId'], 'client1');
      expect(data['trainingCompanyId'], 'comp1');
    });

    test('stores preferredDates as single-item list', () async {
      await seedCompany('comp1', 'owner1');

      await service.createRequest(
        trainingCompanyId: 'comp1',
        clientId: 'client1',
        title: 'Test',
        preferredDateIso: '2024-07-01',
      );

      final snap = await fakeFirestore.collection('course_requests').get();
      final data = snap.docs.first.data();
      expect(data['preferredDates'], ['2024-07-01']);
    });

    test('sets preferredDates to null when not provided', () async {
      await seedCompany('comp1', 'owner1');

      await service.createRequest(
        trainingCompanyId: 'comp1',
        clientId: 'client1',
        title: 'Test',
      );

      final snap = await fakeFirestore.collection('course_requests').get();
      expect(snap.docs.first.data()['preferredDates'], isNull);
    });

    test('sends notification to company owner', () async {
      await seedCompany('comp1', 'owner1');

      await service.createRequest(
        trainingCompanyId: 'comp1',
        clientId: 'client1',
        title: 'My Course',
      );

      final notifs = await fakeFirestore
          .collection('notifications')
          .where('recipientId', isEqualTo: 'owner1')
          .get();
      expect(notifs.docs.length, 1);
      expect(notifs.docs.first.data()['type'], 'request_submitted');
    });
  });

  group('RequestsService.getRequestsByCompany', () {
    test('returns requests for the company', () async {
      await seedCompany('comp1', 'owner1');
      await service.createRequest(
          trainingCompanyId: 'comp1', clientId: 'cl', title: 'T1');
      await service.createRequest(
          trainingCompanyId: 'comp2', clientId: 'cl', title: 'T2');

      final requests = await service.getRequestsByCompany('comp1');
      expect(requests.length, 1);
      expect(requests.first.trainingCompanyId, 'comp1');
    });
  });

  group('RequestsService.getRequestsByClient', () {
    test('returns requests for the client', () async {
      await seedCompany('comp1', 'owner1');
      await service.createRequest(
          trainingCompanyId: 'comp1', clientId: 'client1', title: 'T1');
      await service.createRequest(
          trainingCompanyId: 'comp1', clientId: 'client2', title: 'T2');

      final requests = await service.getRequestsByClient('client1');
      expect(requests.length, 1);
      expect(requests.first.clientId, 'client1');
    });
  });

  group('RequestsService.markRequestReviewed', () {
    test('changes status from pending to reviewed', () async {
      await seedCompany('comp1', 'owner1');
      await service.createRequest(
          trainingCompanyId: 'comp1', clientId: 'cl', title: 'T');

      final snap = await fakeFirestore.collection('course_requests').get();
      final id = snap.docs.first.id;

      await service.markRequestReviewed(id);

      final req = await service.getRequest(id);
      expect(req!.status, 'reviewed');
    });

    test('does not change status if not pending', () async {
      final ref = await fakeFirestore.collection('course_requests').add({
        'trainingCompanyId': 'comp1',
        'clientId': 'cl',
        'title': 'T',
        'status': 'approved',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-01T00:00:00.000Z',
      });

      await service.markRequestReviewed(ref.id);

      final req = await service.getRequest(ref.id);
      expect(req!.status, 'approved');
    });
  });

  group('RequestsService.declineRequest', () {
    test('sets status to declined with reason', () async {
      final ref = await fakeFirestore.collection('course_requests').add({
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'My Course',
        'status': 'pending',
        'createdAt': '',
        'updatedAt': '',
      });

      await service.declineRequest(ref.id, 'No availability');

      final req = await service.getRequest(ref.id);
      expect(req!.status, 'declined');
      expect(req.declineReason, 'No availability');
    });

    test('sends notification to client on decline', () async {
      final ref = await fakeFirestore.collection('course_requests').add({
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'My Course',
        'status': 'pending',
        'createdAt': '',
        'updatedAt': '',
      });

      await service.declineRequest(ref.id, 'Busy');

      final notifs = await fakeFirestore
          .collection('notifications')
          .where('recipientId', isEqualTo: 'client1')
          .get();
      expect(notifs.docs.length, 1);
      expect(notifs.docs.first.data()['type'], 'request_declined');
    });
  });

  group('RequestsService.approveRequest', () {
    test('creates a course and updates request status to approved', () async {
      final ref = await fakeFirestore.collection('course_requests').add({
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'Leadership',
        'topic': 'Management',
        'status': 'pending',
        'createdAt': '',
        'updatedAt': '',
      });

      final courseId = await service.approveRequest(
        ref.id,
        'trainer1',
        DateTime(2024, 6, 15, 9, 0),
      );

      expect(courseId, isNotEmpty);

      // Request should be approved
      final req = await service.getRequest(ref.id);
      expect(req!.status, 'approved');

      // Course should exist
      final courseDoc =
          await fakeFirestore.collection('courses').doc(courseId).get();
      expect(courseDoc.exists, isTrue);
      expect(courseDoc.data()!['title'], 'Leadership');
      expect(courseDoc.data()!['trainerId'], 'trainer1');
      expect(courseDoc.data()!['status'], 'pending_trainer');
    });

    test('throws when request not found', () async {
      await expectLater(
        service.approveRequest('nonexistent', 'trainer1', DateTime.now()),
        throwsException,
      );
    });

    test('throws when request already processed', () async {
      final ref = await fakeFirestore.collection('course_requests').add({
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'T',
        'status': 'approved',
        'createdAt': '',
        'updatedAt': '',
      });

      await expectLater(
        service.approveRequest(ref.id, 'trainer1', DateTime.now()),
        throwsException,
      );
    });

    test('sends notifications to client and trainer on approval', () async {
      final ref = await fakeFirestore.collection('course_requests').add({
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'title': 'Leadership',
        'status': 'pending',
        'createdAt': '',
        'updatedAt': '',
      });

      await service.approveRequest(
        ref.id,
        'trainer1',
        DateTime(2024, 6, 15, 9, 0),
      );

      final clientNotifs = await fakeFirestore
          .collection('notifications')
          .where('recipientId', isEqualTo: 'client1')
          .get();
      expect(clientNotifs.docs.length, 1);
      expect(clientNotifs.docs.first.data()['type'], 'request_approved');

      final trainerNotifs = await fakeFirestore
          .collection('notifications')
          .where('recipientId', isEqualTo: 'trainer1')
          .get();
      expect(trainerNotifs.docs.length, 1);
      expect(trainerNotifs.docs.first.data()['type'], 'course_assigned');
    });
  });

  group('RequestsService.getRequest', () {
    test('returns null for nonexistent request', () async {
      final req = await service.getRequest('nonexistent');
      expect(req, isNull);
    });
  });
}
