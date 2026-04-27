import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/services/venues_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late VenuesService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = VenuesService(firestore: fakeFirestore);
  });

  Future<String> addVenue({
    String companyId = 'comp1',
    String name = 'Grand Hall',
    String address = '1 Main St',
    int? capacity,
  }) async {
    final ref = await fakeFirestore.collection('venues').add({
      'trainingCompanyId': companyId,
      'name': name,
      'address': address,
      if (capacity != null) 'capacity': capacity,
    });
    return ref.id;
  }

  group('VenuesService.getVenues', () {
    test('returns venues for the given company', () async {
      await addVenue(companyId: 'comp1', name: 'Hall A');
      await addVenue(companyId: 'comp1', name: 'Hall B');
      await addVenue(companyId: 'comp2', name: 'Other');

      final venues = await service.getVenues('comp1');
      expect(venues.length, 2);
      expect(venues.every((v) => v.trainingCompanyId == 'comp1'), isTrue);
    });

    test('returns empty list when company has no venues', () async {
      final venues = await service.getVenues('nobody');
      expect(venues, isEmpty);
    });

    test('returns Venue objects with correct fields', () async {
      await addVenue(name: 'Conference Room', address: '5 Office Park', capacity: 30);

      final venues = await service.getVenues('comp1');
      expect(venues.first.name, 'Conference Room');
      expect(venues.first.address, '5 Office Park');
      expect(venues.first.capacity, 30);
    });
  });

  group('VenuesService.deleteVenue', () {
    test('removes the venue document', () async {
      final id = await addVenue();

      await service.deleteVenue(id);

      final doc = await fakeFirestore.collection('venues').doc(id).get();
      expect(doc.exists, isFalse);
    });
  });

  group('VenuesService.updateVenue', () {
    test('updates name, address, and capacity', () async {
      final id = await addVenue(name: 'Old Name', address: 'Old Address');

      await service.updateVenue(
        id,
        name: 'New Name',
        address: 'New Address',
        capacity: 50,
      );

      final doc = await fakeFirestore.collection('venues').doc(id).get();
      expect(doc.data()!['name'], 'New Name');
      expect(doc.data()!['address'], 'New Address');
      expect(doc.data()!['capacity'], 50);
    });

    test('can clear capacity by setting to null', () async {
      final id = await addVenue(capacity: 100);

      await service.updateVenue(id, name: 'Hall', address: 'Addr', capacity: null);

      final doc = await fakeFirestore.collection('venues').doc(id).get();
      expect(doc.data()!['capacity'], isNull);
    });
  });
}
