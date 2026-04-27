import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/document.dart';

void main() {
  group('CourseDocument.fromFirestore', () {
    test('parses all fields correctly', () {
      final data = {
        'courseId': 'course1',
        'courseNumber': 'TT-2024-001',
        'trainingCompanyId': 'comp1',
        'clientId': 'client1',
        'uploadedBy': 'user1',
        'uploaderRole': 'training_company',
        'type': 'attendance_sheet',
        'fileName': 'attendance.pdf',
        'downloadUrl': 'https://example.com/file.pdf',
        'storagePath': 'documents/comp1/course1/attendance.pdf',
        'createdAt': '2024-06-01T10:00:00.000Z',
      };

      final doc = CourseDocument.fromFirestore('doc1', data);

      expect(doc.id, 'doc1');
      expect(doc.courseId, 'course1');
      expect(doc.courseNumber, 'TT-2024-001');
      expect(doc.trainingCompanyId, 'comp1');
      expect(doc.clientId, 'client1');
      expect(doc.uploadedBy, 'user1');
      expect(doc.uploaderRole, 'training_company');
      expect(doc.type, 'attendance_sheet');
      expect(doc.fileName, 'attendance.pdf');
      expect(doc.downloadUrl, 'https://example.com/file.pdf');
      expect(doc.storagePath, 'documents/comp1/course1/attendance.pdf');
      expect(doc.createdAt, '2024-06-01T10:00:00.000Z');
    });

    test('defaults type to other when missing', () {
      final doc = CourseDocument.fromFirestore('id', {});
      expect(doc.type, 'other');
    });

    test('defaults string fields to empty string when missing', () {
      final doc = CourseDocument.fromFirestore('id', {});
      expect(doc.courseId, '');
      expect(doc.fileName, '');
      expect(doc.downloadUrl, '');
      expect(doc.clientId, '');
    });

    test('parses clientId field correctly', () {
      final data = {'clientId': 'client-abc'};
      final doc = CourseDocument.fromFirestore('id', data);
      expect(doc.clientId, 'client-abc');
    });
  });

  group('DocumentType.label', () {
    test('returns correct label for pre_course_pack', () {
      expect(DocumentType.label('pre_course_pack'), 'Pre-Course Pack');
    });

    test('returns correct label for attendance_sheet', () {
      expect(DocumentType.label('attendance_sheet'), 'Attendance Sheet');
    });

    test('returns correct label for sign_in_sheet', () {
      expect(DocumentType.label('sign_in_sheet'), 'Sign-In Sheet');
    });

    test('returns correct label for evaluation_form', () {
      expect(DocumentType.label('evaluation_form'), 'Evaluation Form');
    });

    test('returns correct label for venue_details', () {
      expect(DocumentType.label('venue_details'), 'Venue Details');
    });

    test('returns Document for unknown type', () {
      expect(DocumentType.label('unknown_type'), 'Document');
    });
  });

  group('DocumentType.description', () {
    test('returns description for attendance_sheet', () {
      expect(
        DocumentType.description('attendance_sheet'),
        'Record of delegates who attended',
      );
    });

    test('returns description for sign_in_sheet', () {
      expect(
        DocumentType.description('sign_in_sheet'),
        'Physical sign-in sheet from the session',
      );
    });

    test('returns description for evaluation_form', () {
      expect(
        DocumentType.description('evaluation_form'),
        'Completed delegate evaluation/feedback forms',
      );
    });

    test('returns empty string for unknown type', () {
      expect(DocumentType.description('other'), '');
    });
  });

  group('DocumentType.trainerRequired', () {
    test('contains attendance_sheet', () {
      expect(DocumentType.trainerRequired, contains('attendance_sheet'));
    });

    test('contains sign_in_sheet', () {
      expect(DocumentType.trainerRequired, contains('sign_in_sheet'));
    });

    test('contains evaluation_form', () {
      expect(DocumentType.trainerRequired, contains('evaluation_form'));
    });

    test('does not contain pre_course_pack', () {
      expect(
          DocumentType.trainerRequired, isNot(contains('pre_course_pack')));
    });
  });
}
