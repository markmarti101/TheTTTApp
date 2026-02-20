class CourseRequest {
  final String id;
  final String trainingCompanyId;
  final String clientId;
  final String title;
  final String? topic;
  final List<String>? preferredDates;
  final String? notes;
  final String status;
  final String? declineReason;
  final String createdAt;
  final String updatedAt;

  CourseRequest({
    required this.id,
    required this.trainingCompanyId,
    required this.clientId,
    required this.title,
    this.topic,
    this.preferredDates,
    this.notes,
    required this.status,
    this.declineReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CourseRequest.fromFirestore(String id, Map<String, dynamic> data) {
    return CourseRequest(
      id: id,
      trainingCompanyId: data['trainingCompanyId'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      topic: data['topic'] as String?,
      preferredDates: (data['preferredDates'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      notes: data['notes'] as String?,
      status: data['status'] as String? ?? 'pending',
      declineReason: data['declineReason'] as String?,
      createdAt: data['createdAt'] as String? ?? '',
      updatedAt: data['updatedAt'] as String? ?? '',
    );
  }
}
