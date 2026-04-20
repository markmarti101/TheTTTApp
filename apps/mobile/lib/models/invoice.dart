class Invoice {
  final String id;
  final String invoiceNumber;
  final String courseId;
  final String courseTitle;
  final String clientId;
  final String trainingCompanyId;
  final double amount;
  final String status; // draft | sent | paid | overdue
  final DateTime dueDate;
  final String? poNumber;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.courseId,
    required this.courseTitle,
    required this.clientId,
    required this.trainingCompanyId,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.poNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invoice.fromFirestore(String id, Map<String, dynamic> data) {
    return Invoice(
      id: id,
      invoiceNumber: data['invoiceNumber'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      courseTitle: data['courseTitle'] as String? ?? '',
      clientId: data['clientId'] as String? ?? '',
      trainingCompanyId: data['trainingCompanyId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'draft',
      dueDate: _parseDate(data['dueDate']),
      poNumber: data['poNumber'] as String?,
      notes: data['notes'] as String?,
      createdAt: data['createdAt'] as String? ?? '',
      updatedAt: data['updatedAt'] as String? ?? '',
    );
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.now().add(const Duration(days: 30));
    }
    return DateTime.now().add(const Duration(days: 30));
  }

  bool get isOverdue =>
      status != 'paid' && dueDate.isBefore(DateTime.now());
}
