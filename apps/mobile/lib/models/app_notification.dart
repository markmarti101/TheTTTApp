class AppNotification {
  final String id;
  final String recipientId;
  final String title;
  final String body;
  final String type;
  final String? relatedId;
  final bool read;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(String id, Map<String, dynamic> d) =>
      AppNotification(
        id: id,
        recipientId: d['recipientId'] as String? ?? '',
        title: d['title'] as String? ?? '',
        body: d['body'] as String? ?? '',
        type: d['type'] as String? ?? '',
        relatedId: d['relatedId'] as String?,
        read: d['read'] as bool? ?? false,
        createdAt: d['createdAt'] as String? ?? '',
      );
}
