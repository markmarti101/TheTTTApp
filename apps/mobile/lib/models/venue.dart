class Venue {
  final String id;
  final String name;
  final String address;
  final String trainingCompanyId;
  final String? clientId;
  final int? capacity;
  final String? detailsDocumentUrl;

  Venue({
    required this.id,
    required this.name,
    required this.address,
    required this.trainingCompanyId,
    this.clientId,
    this.capacity,
    this.detailsDocumentUrl,
  });

  factory Venue.fromFirestore(String id, Map<String, dynamic> data) {
    final capacityRaw = data['capacity'];
    int? capacity;
    if (capacityRaw is int) {
      capacity = capacityRaw;
    } else if (capacityRaw is num) {
      capacity = capacityRaw.toInt();
    }

    return Venue(
      id: id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      trainingCompanyId: data['trainingCompanyId'] as String? ?? '',
      clientId: data['clientId'] as String?,
      capacity: capacity,
      detailsDocumentUrl: data['detailsDocumentUrl'] as String?,
    );
  }
}

