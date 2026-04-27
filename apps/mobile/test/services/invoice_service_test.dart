import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/services/invoice_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late InvoiceService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = InvoiceService(firestore: fakeFirestore);
  });

  group('InvoiceService.createInvoice', () {
    test('creates invoice document and returns id', () async {
      final dueDate = DateTime(2024, 7, 1);
      final id = await service.createInvoice(
        courseId: 'course1',
        courseTitle: 'First Aid',
        clientId: 'client1',
        trainingCompanyId: 'comp1',
        amount: 1500.0,
        dueDate: dueDate,
      );

      expect(id, isNotEmpty);
      final doc = await fakeFirestore.collection('invoices').doc(id).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['courseId'], 'course1');
      expect(data['courseTitle'], 'First Aid');
      expect(data['amount'], 1500.0);
      expect(data['status'], 'draft');
    });

    test('generates a unique invoice number', () async {
      final id1 = await service.createInvoice(
        courseId: 'c1',
        courseTitle: 'T1',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        dueDate: DateTime(2024, 7, 1),
      );
      final id2 = await service.createInvoice(
        courseId: 'c2',
        courseTitle: 'T2',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 200,
        dueDate: DateTime(2024, 7, 1),
      );

      final doc1 = await fakeFirestore.collection('invoices').doc(id1).get();
      final doc2 = await fakeFirestore.collection('invoices').doc(id2).get();
      expect(doc1.data()!['invoiceNumber'],
          isNot(doc2.data()!['invoiceNumber']));
    });

    test('stores optional poNumber and notes', () async {
      final id = await service.createInvoice(
        courseId: 'c',
        courseTitle: 'T',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        dueDate: DateTime(2024, 7, 1),
        poNumber: 'PO-999',
        notes: 'Net 30',
      );

      final doc = await fakeFirestore.collection('invoices').doc(id).get();
      expect(doc.data()!['poNumber'], 'PO-999');
      expect(doc.data()!['notes'], 'Net 30');
    });
  });

  group('InvoiceService.getInvoice', () {
    test('returns invoice by id', () async {
      final id = await service.createInvoice(
        courseId: 'c1',
        courseTitle: 'Leadership',
        clientId: 'cl1',
        trainingCompanyId: 'comp1',
        amount: 750.0,
        dueDate: DateTime(2024, 8, 1),
      );

      final invoice = await service.getInvoice(id);
      expect(invoice, isNotNull);
      expect(invoice!.courseTitle, 'Leadership');
      expect(invoice.amount, 750.0);
    });

    test('returns null when invoice does not exist', () async {
      final invoice = await service.getInvoice('nonexistent');
      expect(invoice, isNull);
    });
  });

  group('InvoiceService.getInvoiceByCourse', () {
    test('returns invoice for given courseId', () async {
      await service.createInvoice(
        courseId: 'course1',
        courseTitle: 'First Aid',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 500,
        dueDate: DateTime(2024, 7, 1),
      );

      final invoice = await service.getInvoiceByCourse('course1');
      expect(invoice, isNotNull);
      expect(invoice!.courseId, 'course1');
    });

    test('returns null when no invoice for courseId', () async {
      final invoice = await service.getInvoiceByCourse('no-course');
      expect(invoice, isNull);
    });
  });

  group('InvoiceService.updateStatus', () {
    test('updates status field', () async {
      final id = await service.createInvoice(
        courseId: 'c',
        courseTitle: 'T',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        dueDate: DateTime(2024, 7, 1),
      );

      await service.updateStatus(id, 'sent');

      final doc = await fakeFirestore.collection('invoices').doc(id).get();
      expect(doc.data()!['status'], 'sent');
    });

    test('can mark invoice as paid', () async {
      final id = await service.createInvoice(
        courseId: 'c',
        courseTitle: 'T',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        dueDate: DateTime(2024, 7, 1),
      );

      await service.updateStatus(id, 'paid');

      final invoice = await service.getInvoice(id);
      expect(invoice!.status, 'paid');
      expect(invoice.isOverdue, isFalse);
    });
  });

  group('InvoiceService.deleteInvoice', () {
    test('removes invoice document', () async {
      final id = await service.createInvoice(
        courseId: 'c',
        courseTitle: 'T',
        clientId: 'cl',
        trainingCompanyId: 'comp',
        amount: 100,
        dueDate: DateTime(2024, 7, 1),
      );

      await service.deleteInvoice(id);

      final invoice = await service.getInvoice(id);
      expect(invoice, isNull);
    });
  });

  group('InvoiceService.getInvoicesByCompany', () {
    test('returns only invoices for the given company', () async {
      await service.createInvoice(
          courseId: 'c1',
          courseTitle: 'T1',
          clientId: 'cl',
          trainingCompanyId: 'comp1',
          amount: 100,
          dueDate: DateTime(2024, 7, 1));
      await service.createInvoice(
          courseId: 'c2',
          courseTitle: 'T2',
          clientId: 'cl',
          trainingCompanyId: 'comp2',
          amount: 200,
          dueDate: DateTime(2024, 7, 1));

      final invoices = await service.getInvoicesByCompany('comp1');
      expect(invoices.length, 1);
      expect(invoices.first.trainingCompanyId, 'comp1');
    });
  });
}
