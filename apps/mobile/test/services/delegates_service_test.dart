import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/services/delegates_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DelegatesService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = DelegatesService(firestore: fakeFirestore);
  });

  group('DelegatesService.addDelegate', () {
    test('adds delegate to correct subcollection', () async {
      await service.addDelegate(
        'client1',
        name: 'Jane Doe',
        email: 'Jane@Example.com',
      );

      final snap =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['name'], 'Jane Doe');
      expect(data['email'], 'jane@example.com'); // lowercased
    });

    test('trims whitespace from name and email', () async {
      await service.addDelegate(
        'client1',
        name: '  John Smith  ',
        email: '  john@example.com  ',
      );

      final snap =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      final data = snap.docs.first.data();
      expect(data['name'], 'John Smith');
      expect(data['email'], 'john@example.com');
    });

    test('stores accessibilityNeeds when non-empty', () async {
      await service.addDelegate(
        'client1',
        name: 'Test',
        email: 'test@test.com',
        accessibilityNeeds: 'Wheelchair',
      );

      final snap =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      expect(snap.docs.first.data()['accessibilityNeeds'], 'Wheelchair');
    });

    test('omits accessibilityNeeds when blank', () async {
      await service.addDelegate(
        'client1',
        name: 'Test',
        email: 'test@test.com',
        accessibilityNeeds: '   ',
      );

      final snap =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      expect(snap.docs.first.data().containsKey('accessibilityNeeds'), isFalse);
    });

    test('stores dietaryRequirements when non-empty', () async {
      await service.addDelegate(
        'client1',
        name: 'Test',
        email: 'test@test.com',
        dietaryRequirements: 'Vegan',
      );

      final snap =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      expect(snap.docs.first.data()['dietaryRequirements'], 'Vegan');
    });
  });

  group('DelegatesService.getDelegates', () {
    test('returns all delegates for a client', () async {
      await service.addDelegate('client1', name: 'Alice', email: 'a@test.com');
      await service.addDelegate('client1', name: 'Bob', email: 'b@test.com');
      await service.addDelegate('client2', name: 'Carol', email: 'c@test.com');

      final delegates = await service.getDelegates('client1');
      expect(delegates.length, 2);
    });

    test('returns empty list when client has no delegates', () async {
      final delegates = await service.getDelegates('nobody');
      expect(delegates, isEmpty);
    });

    test('returns Delegate objects with correct fields', () async {
      await service.addDelegate(
        'client1',
        name: 'Jane',
        email: 'jane@test.com',
        accessibilityNeeds: 'Ramp',
      );

      final delegates = await service.getDelegates('client1');
      expect(delegates.first.name, 'Jane');
      expect(delegates.first.email, 'jane@test.com');
      expect(delegates.first.accessibilityNeeds, 'Ramp');
    });
  });

  group('DelegatesService.updateDelegate', () {
    test('updates name and email', () async {
      await service.addDelegate('client1', name: 'Old Name', email: 'old@test.com');
      final snap =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      final id = snap.docs.first.id;

      await service.updateDelegate(
        'client1',
        id,
        name: 'New Name',
        email: 'new@test.com',
      );

      final updated =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').doc(id).get();
      expect(updated.data()!['name'], 'New Name');
      expect(updated.data()!['email'], 'new@test.com');
    });

    test('clears accessibilityNeeds when set to empty', () async {
      await service.addDelegate(
        'client1',
        name: 'Test',
        email: 't@test.com',
        accessibilityNeeds: 'Wheelchair',
      );
      final snap =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      final id = snap.docs.first.id;

      await service.updateDelegate(
        'client1',
        id,
        name: 'Test',
        email: 't@test.com',
        accessibilityNeeds: '',
      );

      final updated =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').doc(id).get();
      expect(updated.data()!['accessibilityNeeds'], isNull);
    });
  });

  group('DelegatesService.removeDelegate', () {
    test('removes the specified delegate', () async {
      await service.addDelegate('client1', name: 'ToDelete', email: 'd@test.com');
      await service.addDelegate('client1', name: 'ToKeep', email: 'k@test.com');

      final snap =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      final idToDelete = snap.docs.first.id;

      await service.removeDelegate('client1', idToDelete);

      final after =
          await fakeFirestore.collection('users').doc('client1').collection('delegates').get();
      expect(after.docs.length, 1);
      expect(after.docs.first.id, isNot(idToDelete));
    });
  });
}
