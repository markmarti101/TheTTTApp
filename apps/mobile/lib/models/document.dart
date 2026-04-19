class CourseDocument {
  final String id;
  final String courseId;
  final String courseNumber;
  final String trainingCompanyId;
  final String uploadedBy;
  final String uploaderRole; // 'training_company' | 'freelance_trainer'
  final String type;
  final String fileName;
  final String downloadUrl;
  final String storagePath;
  final String createdAt;

  CourseDocument({
    required this.id,
    required this.courseId,
    required this.courseNumber,
    required this.trainingCompanyId,
    required this.uploadedBy,
    required this.uploaderRole,
    required this.type,
    required this.fileName,
    required this.downloadUrl,
    required this.storagePath,
    required this.createdAt,
  });

  factory CourseDocument.fromFirestore(String id, Map<String, dynamic> d) =>
      CourseDocument(
        id: id,
        courseId: d['courseId'] as String? ?? '',
        courseNumber: d['courseNumber'] as String? ?? '',
        trainingCompanyId: d['trainingCompanyId'] as String? ?? '',
        uploadedBy: d['uploadedBy'] as String? ?? '',
        uploaderRole: d['uploaderRole'] as String? ?? '',
        type: d['type'] as String? ?? 'other',
        fileName: d['fileName'] as String? ?? '',
        downloadUrl: d['downloadUrl'] as String? ?? '',
        storagePath: d['storagePath'] as String? ?? '',
        createdAt: d['createdAt'] as String? ?? '',
      );
}

class DocumentType {
  static const preCoursePackk = 'pre_course_pack';
  static const attendanceSheet = 'attendance_sheet';
  static const signInSheet = 'sign_in_sheet';
  static const evaluationForm = 'evaluation_form';
  static const venueDetails = 'venue_details';
  static const other = 'other';

  static const List<String> trainerRequired = [
    attendanceSheet,
    signInSheet,
    evaluationForm,
  ];

  static String label(String type) => switch (type) {
        'pre_course_pack' => 'Pre-Course Pack',
        'attendance_sheet' => 'Attendance Sheet',
        'sign_in_sheet' => 'Sign-In Sheet',
        'evaluation_form' => 'Evaluation Form',
        'venue_details' => 'Venue Details',
        _ => 'Document',
      };

  static String description(String type) => switch (type) {
        'attendance_sheet' => 'Record of delegates who attended',
        'sign_in_sheet' => 'Physical sign-in sheet from the session',
        'evaluation_form' => 'Completed delegate evaluation/feedback forms',
        _ => '',
      };
}
