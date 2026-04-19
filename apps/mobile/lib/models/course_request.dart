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

  // Booking form fields
  final int? delegateCount;
  final String? poNumber;
  final String? venuePreference;
  final String? venueSetup; // 'classroom' | 'theatre' | 'cabaret' | 'boardroom'
  final String? cateringNotes;
  final String? accessibilityNotes;

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
    this.delegateCount,
    this.poNumber,
    this.venuePreference,
    this.venueSetup,
    this.cateringNotes,
    this.accessibilityNotes,
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
      delegateCount: (data['delegateCount'] as num?)?.toInt(),
      poNumber: data['poNumber'] as String?,
      venuePreference: data['venuePreference'] as String?,
      venueSetup: data['venueSetup'] as String?,
      cateringNotes: data['cateringNotes'] as String?,
      accessibilityNotes: data['accessibilityNotes'] as String?,
    );
  }
}
