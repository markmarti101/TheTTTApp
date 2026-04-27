import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/screens/audit_trail_screen.dart';
import 'package:training_triangle/services/audit_log_service.dart';

AuditLogService _fakeService([FakeFirebaseFirestore? fakeFirestore]) {
  return AuditLogService(firestore: fakeFirestore ?? FakeFirebaseFirestore());
}

Widget _buildSubject({String companyId = 'comp1', AuditLogService? service}) {
  return MaterialApp(
    home: AuditTrailScreen(
      companyId: companyId,
      service: service ?? _fakeService(),
    ),
  );
}

void main() {
  group('AuditTrailScreen', () {
    testWidgets('renders Audit Trail title', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      expect(find.text('Audit Trail'), findsOneWidget);
    });

    testWidgets('shows loading indicator before data loads', (tester) async {
      await tester.pumpWidget(_buildSubject());

      // Before first pump settles — loading state should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when there are no entries', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('No activity yet'), findsOneWidget);
    });

    testWidgets('shows entry list when data is loaded', (tester) async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('audit_log').add({
        'companyId': 'comp1',
        'action': 'course_created',
        'description': 'Course "First Aid" created',
        'performedBy': 'admin',
        'createdAt': '2024-06-01T10:00:00.000Z',
      });

      final service = _fakeService(fakeFs);
      await tester.pumpWidget(_buildSubject(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Course "First Aid" created'), findsOneWidget);
    });

    testWidgets('shows correct action label for course_created', (tester) async {
      final fakeFs = FakeFirebaseFirestore();
      await fakeFs.collection('audit_log').add({
        'companyId': 'comp1',
        'action': 'course_created',
        'description': 'New course',
        'performedBy': 'admin',
        'createdAt': '2024-06-01T10:00:00.000Z',
      });

      await tester.pumpWidget(_buildSubject(service: _fakeService(fakeFs)));
      await tester.pumpAndSettle();

      expect(find.text('Course Created'), findsOneWidget);
    });

    testWidgets('renders subtitle text', (tester) async {
      await tester.pumpWidget(_buildSubject());
      await tester.pump();

      expect(find.text('Log of key events'), findsOneWidget);
    });

    testWidgets('renders without crashing for empty companyId', (tester) async {
      await tester.pumpWidget(_buildSubject(companyId: ''));
      await tester.pumpAndSettle();

      expect(find.byType(AuditTrailScreen), findsOneWidget);
    });
  });
}
