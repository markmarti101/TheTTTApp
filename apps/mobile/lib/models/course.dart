class Course {
  final String id;
  final String courseNumber;
  final String title;
  final String? topic;
  final String trainingCompanyId;
  final String clientId;
  final String trainerId;
  final String? venueId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final List<String>? delegateIds;
  final String? notes;
  final String? poNumber;
  final String createdAt;
  final String updatedAt;

  Course({
    required this.id,
    required this.courseNumber,
    required this.title,
    this.topic,
    required this.trainingCompanyId,
    required this.clientId,
    required this.trainerId,
    this.venueId,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.delegateIds,
    this.notes,
    this.poNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Course.fromFirestore(String id, Map<String, dynamic> data) {
    return Course(
      id: id,
      courseNumber: data['courseNumber'] as String? ?? '',
      title: data['title'] as String? ?? '',
      topic: data['topic'] as String?,
      trainingCompanyId: data['trainingCompanyId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      trainerId: data['trainerId'] as String? ?? '',
      venueId: data['venueId'] as String?,
      startDate: _parseIsoDate(data['startDate']),
      endDate: _parseIsoDate(data['endDate']),
      status: data['status'] as String? ?? 'pending_trainer',
      delegateIds: (data['delegateIds'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      notes: data['notes'] as String?,
      poNumber: data['poNumber'] as String?,
      createdAt: data['createdAt'] as String? ?? '',
      updatedAt: data['updatedAt'] as String? ?? '',
    );
  }

  static DateTime _parseIsoDate(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

