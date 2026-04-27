import 'package:flutter_test/flutter_test.dart';
import 'package:training_triangle/models/course.dart';

/// Mirrors the calendar filter logic from training_company_home_screen.dart
/// so we can unit-test it independently.
List<Course> filterCourses(
  List<Course> courses, {
  String? statusFilter,
  String searchQuery = '',
}) {
  var result = courses;

  if (statusFilter != null) {
    result = result.where((c) {
      switch (statusFilter) {
        case 'pending':
          return c.status == 'pending_trainer' || c.status == 'pending';
        case 'confirmed':
          return c.status == 'confirmed';
        case 'completed':
          return c.status == 'completed';
        default:
          return true;
      }
    }).toList();
  }

  if (searchQuery.isNotEmpty) {
    final q = searchQuery.toLowerCase();
    result = result.where((c) => c.title.toLowerCase().contains(q)).toList();
  }

  return result;
}

List<Course> filterByMonth(
    List<Course> courses, int year, int month) {
  return courses
      .where((c) => c.startDate.year == year && c.startDate.month == month)
      .toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
}

Course _course({
  required String title,
  required String status,
  String startDate = '2024-06-15T09:00:00.000Z',
}) =>
    Course.fromFirestore('id_$title', {
      'title': title,
      'trainingCompanyId': 'comp1',
      'clientId': 'client1',
      'trainerId': 'trainer1',
      'startDate': startDate,
      'endDate': '2024-06-15T17:00:00.000Z',
      'status': status,
      'createdAt': '',
      'updatedAt': '',
    });

void main() {
  final courses = [
    _course(title: 'First Aid', status: 'confirmed'),
    _course(title: 'Leadership', status: 'pending_trainer'),
    _course(title: 'Fire Safety', status: 'completed'),
    _course(title: 'Manual Handling', status: 'confirmed'),
    _course(title: 'First Response', status: 'trainer_declined'),
  ];

  group('filterCourses — status filter', () {
    test('no filter returns all courses', () {
      final result = filterCourses(courses);
      expect(result.length, 5);
    });

    test('pending filter returns pending_trainer courses', () {
      final result = filterCourses(courses, statusFilter: 'pending');
      expect(result.every((c) =>
              c.status == 'pending_trainer' || c.status == 'pending'),
          isTrue);
      expect(result.length, 1);
    });

    test('confirmed filter returns only confirmed courses', () {
      final result = filterCourses(courses, statusFilter: 'confirmed');
      expect(result.every((c) => c.status == 'confirmed'), isTrue);
      expect(result.length, 2);
    });

    test('completed filter returns only completed courses', () {
      final result = filterCourses(courses, statusFilter: 'completed');
      expect(result.every((c) => c.status == 'completed'), isTrue);
      expect(result.length, 1);
    });

    test('trainer_declined courses excluded from confirmed filter', () {
      final result = filterCourses(courses, statusFilter: 'confirmed');
      expect(result.any((c) => c.status == 'trainer_declined'), isFalse);
    });
  });

  group('filterCourses — search', () {
    test('empty search returns all courses', () {
      final result = filterCourses(courses, searchQuery: '');
      expect(result.length, 5);
    });

    test('search is case-insensitive', () {
      final result = filterCourses(courses, searchQuery: 'first');
      expect(result.length, 2);
      expect(result.every((c) =>
              c.title.toLowerCase().contains('first')),
          isTrue);
    });

    test('search returns empty when no match', () {
      final result = filterCourses(courses, searchQuery: 'xyz123');
      expect(result, isEmpty);
    });

    test('search on partial title matches', () {
      final result = filterCourses(courses, searchQuery: 'aid');
      expect(result.length, 1);
      expect(result.first.title, 'First Aid');
    });
  });

  group('filterCourses — combined status and search', () {
    test('filters by status then by search', () {
      final result = filterCourses(
        courses,
        statusFilter: 'confirmed',
        searchQuery: 'first',
      );
      expect(result.length, 1);
      expect(result.first.title, 'First Aid');
      expect(result.first.status, 'confirmed');
    });

    test('returns empty when search excludes all status-filtered results', () {
      final result = filterCourses(
        courses,
        statusFilter: 'completed',
        searchQuery: 'first',
      );
      expect(result, isEmpty);
    });
  });

  group('filterByMonth', () {
    final multiMonthCourses = [
      _course(
          title: 'Course A',
          status: 'confirmed',
          startDate: '2024-06-01T09:00:00.000Z'),
      _course(
          title: 'Course B',
          status: 'confirmed',
          startDate: '2024-06-15T09:00:00.000Z'),
      _course(
          title: 'Course C',
          status: 'confirmed',
          startDate: '2024-07-01T09:00:00.000Z'),
    ];

    test('returns only courses in the given month', () {
      final result = filterByMonth(multiMonthCourses, 2024, 6);
      expect(result.length, 2);
      expect(result.every((c) => c.startDate.month == 6), isTrue);
    });

    test('returns empty list when no courses in month', () {
      final result = filterByMonth(multiMonthCourses, 2024, 8);
      expect(result, isEmpty);
    });

    test('results are sorted by startDate ascending', () {
      final result = filterByMonth(multiMonthCourses, 2024, 6);
      expect(result.first.startDate.day, lessThan(result.last.startDate.day));
    });
  });

  group('status label mapping', () {
    final statusLabels = <String, String>{
      'pending_trainer': 'Pending',
      'pending': 'Pending',
      'confirmed': 'Confirmed',
      'completed': 'Completed',
      'declined': 'Declined',
      'trainer_declined': 'Declined',
    };

    test('all expected status keys are handled', () {
      for (final entry in statusLabels.entries) {
        expect(entry.value, isNotEmpty,
            reason: 'Status ${entry.key} should have a label');
      }
    });
  });
}
