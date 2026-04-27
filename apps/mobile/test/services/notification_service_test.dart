import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/services/notification_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late NotificationService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = NotificationService(firestore: fakeFirestore);
  });

  group('NotificationService.send', () {
    test('creates a notification document', () async {
      await service.send(
        recipientId: 'user1',
        title: 'Test',
        body: 'Hello',
        type: 'course_assigned',
      );

      final snap = await fakeFirestore.collection('notifications').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['recipientId'], 'user1');
      expect(data['title'], 'Test');
      expect(data['body'], 'Hello');
      expect(data['type'], 'course_assigned');
      expect(data['read'], isFalse);
    });

    test('includes relatedId when provided', () async {
      await service.send(
        recipientId: 'user1',
        title: 'T',
        body: 'B',
        type: 'request_approved',
        relatedId: 'course1',
      );

      final snap = await fakeFirestore.collection('notifications').get();
      expect(snap.docs.first.data()['relatedId'], 'course1');
    });

    test('omits relatedId when not provided', () async {
      await service.send(
          recipientId: 'user1', title: 'T', body: 'B', type: 'info');

      final snap = await fakeFirestore.collection('notifications').get();
      expect(snap.docs.first.data().containsKey('relatedId'), isFalse);
    });
  });

  group('NotificationService.getForUser', () {
    test('returns only notifications for the given user', () async {
      await service.send(
          recipientId: 'user1', title: 'A', body: 'B', type: 'info');
      await service.send(
          recipientId: 'user2', title: 'C', body: 'D', type: 'info');

      final notifs = await service.getForUser('user1');
      expect(notifs.length, 1);
      expect(notifs.first.recipientId, 'user1');
    });

    test('returns empty list when user has no notifications', () async {
      final notifs = await service.getForUser('nobody');
      expect(notifs, isEmpty);
    });

    test('returns notifications sorted by createdAt descending', () async {
      await fakeFirestore.collection('notifications').add({
        'recipientId': 'user1',
        'title': 'Old',
        'body': '',
        'type': 'info',
        'read': false,
        'createdAt': '2024-01-01T00:00:00.000Z',
      });
      await fakeFirestore.collection('notifications').add({
        'recipientId': 'user1',
        'title': 'New',
        'body': '',
        'type': 'info',
        'read': false,
        'createdAt': '2024-01-02T00:00:00.000Z',
      });

      final notifs = await service.getForUser('user1');
      expect(notifs.first.title, 'New');
      expect(notifs.last.title, 'Old');
    });
  });

  group('NotificationService.getUnreadCount', () {
    test('returns count of unread notifications for user', () async {
      await service.send(
          recipientId: 'user1', title: 'A', body: '', type: 'info');
      await service.send(
          recipientId: 'user1', title: 'B', body: '', type: 'info');
      await service.send(
          recipientId: 'user2', title: 'C', body: '', type: 'info');

      final count = await service.getUnreadCount('user1');
      expect(count, 2);
    });

    test('returns 0 when all notifications are read', () async {
      final id = (await fakeFirestore.collection('notifications').add({
        'recipientId': 'user1',
        'title': 'T',
        'body': '',
        'type': 'info',
        'read': true,
        'createdAt': '',
      })).id;

      final count = await service.getUnreadCount('user1');
      expect(count, 0);
      expect(id, isNotEmpty);
    });
  });

  group('NotificationService.markRead', () {
    test('sets read to true for the notification', () async {
      final ref = await fakeFirestore.collection('notifications').add({
        'recipientId': 'user1',
        'title': 'T',
        'body': '',
        'type': 'info',
        'read': false,
        'createdAt': '',
      });

      await service.markRead(ref.id);

      final doc =
          await fakeFirestore.collection('notifications').doc(ref.id).get();
      expect(doc.data()!['read'], isTrue);
    });
  });

  group('NotificationService.markAllRead', () {
    test('marks all unread notifications as read for the user', () async {
      await service.send(
          recipientId: 'user1', title: 'A', body: '', type: 'info');
      await service.send(
          recipientId: 'user1', title: 'B', body: '', type: 'info');

      await service.markAllRead('user1');

      final count = await service.getUnreadCount('user1');
      expect(count, 0);
    });
  });

  group('NotificationService.clearAll', () {
    test('removes all notifications for the user', () async {
      await service.send(
          recipientId: 'user1', title: 'A', body: '', type: 'info');
      await service.send(
          recipientId: 'user1', title: 'B', body: '', type: 'info');
      await service.send(
          recipientId: 'user2', title: 'C', body: '', type: 'info');

      await service.clearAll('user1');

      final remaining = await service.getForUser('user1');
      expect(remaining, isEmpty);

      final user2 = await service.getForUser('user2');
      expect(user2.length, 1);
    });
  });

  group('NotificationService.getCompanyOwnerId', () {
    test('returns ownerId from training_companies doc', () async {
      await fakeFirestore
          .collection('training_companies')
          .doc('comp1')
          .set({'ownerId': 'owner1'});

      final ownerId = await service.getCompanyOwnerId('comp1');
      expect(ownerId, 'owner1');
    });

    test('returns null when company does not exist', () async {
      final ownerId = await service.getCompanyOwnerId('nonexistent');
      expect(ownerId, isNull);
    });
  });
}
