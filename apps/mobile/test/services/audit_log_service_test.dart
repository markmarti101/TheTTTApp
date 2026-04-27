import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/services/audit_log_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late AuditLogService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = AuditLogService(firestore: fakeFirestore);
  });

  group('AuditLogService.log', () {
    test('writes entry to audit_log collection', () async {
      await service.log(
        companyId: 'comp1',
        action: 'course_created',
        description: 'Course First Aid created',
        performedBy: 'user1',
      );

      final snap = await fakeFirestore.collection('audit_log').get();
      expect(snap.docs.length, 1);
      final data = snap.docs.first.data();
      expect(data['companyId'], 'comp1');
      expect(data['action'], 'course_created');
      expect(data['description'], 'Course First Aid created');
      expect(data['performedBy'], 'user1');
    });

    test('writes entityId when provided', () async {
      await service.log(
        companyId: 'comp1',
        action: 'delegate_added',
        description: 'Delegate added',
        performedBy: 'user1',
        entityId: 'del1',
      );

      final snap = await fakeFirestore.collection('audit_log').get();
      expect(snap.docs.first.data()['entityId'], 'del1');
    });

    test('omits entityId when not provided', () async {
      await service.log(
        companyId: 'comp1',
        action: 'action',
        description: 'desc',
        performedBy: 'user1',
      );

      final snap = await fakeFirestore.collection('audit_log').get();
      expect(snap.docs.first.data().containsKey('entityId'), isFalse);
    });

    test('does not throw on error', () async {
      // log() catches all exceptions — should complete without throwing
      await expectLater(
        service.log(
          companyId: '',
          action: '',
          description: '',
          performedBy: '',
        ),
        completes,
      );
    });
  });

  group('AuditLogService.getEntries', () {
    test('returns entries for the given companyId', () async {
      await service.log(
          companyId: 'comp1', action: 'a', description: 'd', performedBy: 'u');
      await service.log(
          companyId: 'comp2', action: 'b', description: 'e', performedBy: 'v');

      final entries = await service.getEntries('comp1');
      expect(entries.length, 1);
      expect(entries.first.companyId, 'comp1');
    });

    test('returns empty list when no entries exist', () async {
      final entries = await service.getEntries('nonexistent');
      expect(entries, isEmpty);
    });

    test('returns entries sorted by createdAt descending', () async {
      await fakeFirestore.collection('audit_log').add({
        'companyId': 'comp1',
        'action': 'a',
        'description': 'd',
        'performedBy': 'u',
        'createdAt': '2024-01-01T10:00:00.000Z',
      });
      await fakeFirestore.collection('audit_log').add({
        'companyId': 'comp1',
        'action': 'b',
        'description': 'e',
        'performedBy': 'u',
        'createdAt': '2024-01-02T10:00:00.000Z',
      });

      final entries = await service.getEntries('comp1');
      expect(entries.first.createdAt, '2024-01-02T10:00:00.000Z');
      expect(entries.last.createdAt, '2024-01-01T10:00:00.000Z');
    });

    test('limits results to 200', () async {
      for (var i = 0; i < 205; i++) {
        await fakeFirestore.collection('audit_log').add({
          'companyId': 'comp1',
          'action': 'a',
          'description': 'd',
          'performedBy': 'u',
          'createdAt': '2024-01-01T${i.toString().padLeft(2, '0')}:00:00.000Z',
        });
      }
      final entries = await service.getEntries('comp1');
      expect(entries.length, lessThanOrEqualTo(200));
    });

    test('AuditEntry fields are parsed correctly', () async {
      await fakeFirestore.collection('audit_log').add({
        'companyId': 'comp1',
        'action': 'invoice_sent',
        'description': 'Invoice INV-001 sent',
        'performedBy': 'admin1',
        'entityId': 'inv1',
        'createdAt': '2024-06-01T12:00:00.000Z',
      });

      final entries = await service.getEntries('comp1');
      final entry = entries.first;
      expect(entry.action, 'invoice_sent');
      expect(entry.description, 'Invoice INV-001 sent');
      expect(entry.performedBy, 'admin1');
      expect(entry.entityId, 'inv1');
    });
  });
}
