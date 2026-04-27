import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/invoice.dart';

void main() {
  group('Invoice.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'invoiceNumber': 'INV-2024-001',
        'courseId': 'course1',
        'courseTitle': 'First Aid',
        'clientId': 'client1',
        'trainingCompanyId': 'comp1',
        'amount': 1500.0,
        'status': 'sent',
        'dueDate': '2024-07-01T00:00:00.000Z',
        'poNumber': 'PO-123',
        'notes': 'Net 30',
        'createdAt': '2024-06-01T00:00:00.000Z',
        'updatedAt': '2024-06-01T00:00:00.000Z',
      };

      final invoice = Invoice.fromFirestore('inv1', data);

      expect(invoice.id, 'inv1');
      expect(invoice.invoiceNumber, 'INV-2024-001');
      expect(invoice.courseId, 'course1');
      expect(invoice.courseTitle, 'First Aid');
      expect(invoice.clientId, 'client1');
      expect(invoice.trainingCompanyId, 'comp1');
      expect(invoice.amount, 1500.0);
      expect(invoice.status, 'sent');
      expect(invoice.dueDate.year, 2024);
      expect(invoice.dueDate.month, 7);
      expect(invoice.dueDate.day, 1);
      expect(invoice.poNumber, 'PO-123');
      expect(invoice.notes, 'Net 30');
    });

    test('defaults status to draft when missing', () {
      final invoice = Invoice.fromFirestore('id', {'dueDate': '2099-01-01T00:00:00.000Z'});
      expect(invoice.status, 'draft');
    });

    test('defaults amount to 0.0 when missing', () {
      final invoice = Invoice.fromFirestore('id', {'dueDate': '2099-01-01T00:00:00.000Z'});
      expect(invoice.amount, 0.0);
    });

    test('parses amount from int type', () {
      final data = {'amount': 500, 'dueDate': '2099-01-01T00:00:00.000Z'};
      final invoice = Invoice.fromFirestore('id', data);
      expect(invoice.amount, 500.0);
      expect(invoice.amount, isA<double>());
    });

    test('defaults optional fields to null when missing', () {
      final invoice = Invoice.fromFirestore('id', {'dueDate': '2099-01-01T00:00:00.000Z'});
      expect(invoice.poNumber, isNull);
      expect(invoice.notes, isNull);
    });

    test('defaults string fields to empty string when missing', () {
      final invoice = Invoice.fromFirestore('id', {'dueDate': '2099-01-01T00:00:00.000Z'});
      expect(invoice.invoiceNumber, '');
      expect(invoice.courseId, '');
      expect(invoice.courseTitle, '');
      expect(invoice.clientId, '');
      expect(invoice.trainingCompanyId, '');
    });

    test('falls back to future date when dueDate is invalid string', () {
      final before = DateTime.now();
      final invoice = Invoice.fromFirestore('id', {'dueDate': 'not-a-date'});
      expect(invoice.dueDate.isAfter(before), isTrue);
    });

    test('falls back to future date when dueDate is null', () {
      final before = DateTime.now();
      final invoice = Invoice.fromFirestore('id', {});
      expect(invoice.dueDate.isAfter(before), isTrue);
    });
  });

  group('Invoice.isOverdue', () {
    test('returns true when status is not paid and dueDate is in the past', () {
      final invoice = Invoice(
        id: '1',
        invoiceNumber: 'INV-001',
        courseId: 'c',
        courseTitle: 'T',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        status: 'sent',
        dueDate: DateTime(2000, 1, 1),
        createdAt: '',
        updatedAt: '',
      );
      expect(invoice.isOverdue, isTrue);
    });

    test('returns false when status is paid even if dueDate is in the past', () {
      final invoice = Invoice(
        id: '1',
        invoiceNumber: 'INV-001',
        courseId: 'c',
        courseTitle: 'T',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        status: 'paid',
        dueDate: DateTime(2000, 1, 1),
        createdAt: '',
        updatedAt: '',
      );
      expect(invoice.isOverdue, isFalse);
    });

    test('returns false when dueDate is in the future', () {
      final invoice = Invoice(
        id: '1',
        invoiceNumber: 'INV-001',
        courseId: 'c',
        courseTitle: 'T',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        status: 'sent',
        dueDate: DateTime(2099, 1, 1),
        createdAt: '',
        updatedAt: '',
      );
      expect(invoice.isOverdue, isFalse);
    });

    test('returns true for draft status with past dueDate', () {
      final invoice = Invoice(
        id: '1',
        invoiceNumber: 'INV-001',
        courseId: 'c',
        courseTitle: 'T',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        status: 'draft',
        dueDate: DateTime(2000, 1, 1),
        createdAt: '',
        updatedAt: '',
      );
      expect(invoice.isOverdue, isTrue);
    });
  });
}
