class Resource {
  final String id;
  final String trainingCompanyId;
  final String name;
  final String category; // 'book' | 'equipment' | 'material' | 'other'
  final int totalStock;
  final int reorderThreshold;
  final String unit; // 'copies' | 'units' | 'sets' | 'packs'
  final String createdAt;
  final String updatedAt;

  Resource({
    required this.id,
    required this.trainingCompanyId,
    required this.name,
    required this.category,
    required this.totalStock,
    required this.reorderThreshold,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'trainingCompanyId': trainingCompanyId,
        'name': name,
        'category': category,
        'totalStock': totalStock,
        'reorderThreshold': reorderThreshold,
        'unit': unit,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Resource.fromFirestore(String id, Map<String, dynamic> d) =>
      Resource(
        id: id,
        trainingCompanyId: d['trainingCompanyId'] as String? ?? '',
        name: d['name'] as String? ?? '',
        category: d['category'] as String? ?? 'other',
        totalStock: (d['totalStock'] as num?)?.toInt() ?? 0,
        reorderThreshold: (d['reorderThreshold'] as num?)?.toInt() ?? 0,
        unit: d['unit'] as String? ?? 'units',
        createdAt: d['createdAt'] as String? ?? '',
        updatedAt: d['updatedAt'] as String? ?? '',
      );
}

class ResourceAllocation {
  final String id;
  final String trainingCompanyId;
  final String resourceId;
  final String courseId;
  final String courseTitle;
  final int quantity;
  final String allocatedAt;

  ResourceAllocation({
    required this.id,
    required this.trainingCompanyId,
    required this.resourceId,
    required this.courseId,
    required this.courseTitle,
    required this.quantity,
    required this.allocatedAt,
  });

  Map<String, dynamic> toMap() => {
        'trainingCompanyId': trainingCompanyId,
        'resourceId': resourceId,
        'courseId': courseId,
        'courseTitle': courseTitle,
        'quantity': quantity,
        'allocatedAt': allocatedAt,
      };

  factory ResourceAllocation.fromFirestore(
          String id, Map<String, dynamic> d) =>
      ResourceAllocation(
        id: id,
        trainingCompanyId: d['trainingCompanyId'] as String? ?? '',
        resourceId: d['resourceId'] as String? ?? '',
        courseId: d['courseId'] as String? ?? '',
        courseTitle: d['courseTitle'] as String? ?? '',
        quantity: (d['quantity'] as num?)?.toInt() ?? 0,
        allocatedAt: d['allocatedAt'] as String? ?? '',
      );
}
