import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/venue.dart';

void main() {
  group('Venue.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'name': 'Grand Hall',
        'address': '1 Main Street, London',
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'capacity': 100,
        'detailsDocumentUrl': 'https://example.com/venue.pdf',
      };

      final venue = Venue.fromFirestore('venue1', data);

      expect(venue.id, 'venue1');
      expect(venue.name, 'Grand Hall');
      expect(venue.address, '1 Main Street, London');
      expect(venue.trainingCompanyId, 'comp1');
      expect(venue.clientId, 'client1');
      expect(venue.capacity, 100);
      expect(venue.detailsDocumentUrl, 'https://example.com/venue.pdf');
    });

    test('defaults name and address to empty string when missing', () {
      final venue = Venue.fromFirestore('id', {});
      expect(venue.name, '');
      expect(venue.address, '');
    });

    test('defaults optional fields to null when missing', () {
      final venue = Venue.fromFirestore('id', {});
      expect(venue.clientId, isNull);
      expect(venue.capacity, isNull);
      expect(venue.detailsDocumentUrl, isNull);
    });

    test('parses capacity from double (num) type', () {
      final data = {'capacity': 50.0, 'trainingCompanyId': 'comp1'};
      final venue = Venue.fromFirestore('id', data);
      expect(venue.capacity, 50);
      expect(venue.capacity, isA<int>());
    });

    test('parses capacity from int type', () {
      final data = {'capacity': 75, 'trainingCompanyId': 'comp1'};
      final venue = Venue.fromFirestore('id', data);
      expect(venue.capacity, 75);
    });

    test('capacity remains null when not provided', () {
      final venue = Venue.fromFirestore('id', {'name': 'Test'});
      expect(venue.capacity, isNull);
    });

    test('trainingCompanyId defaults to empty string when missing', () {
      final venue = Venue.fromFirestore('id', {});
      expect(venue.trainingCompanyId, '');
    });

    test('clientId is null when explicitly null in data', () {
      final data = {'clientId': null};
      final venue = Venue.fromFirestore('id', data);
      expect(venue.clientId, isNull);
    });
  });
}
