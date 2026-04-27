class Delegate {
  final String id;
  final String name;
  final String email;
  final String? accessibilityNeeds;
  final String? dietaryRequirements;
  final String addedAt;

  Delegate({
    required this.id,
    required this.name,
    required this.email,
    this.accessibilityNeeds,
    this.dietaryRequirements,
    required this.addedAt,
  });

  bool get hasAccessibility =>
      accessibilityNeeds != null && accessibilityNeeds!.trim().isNotEmpty;
  bool get hasDietary =>
      dietaryRequirements != null && dietaryRequirements!.trim().isNotEmpty;

  factory Delegate.fromFirestore(String id, Map<String, dynamic> data) {
    return Delegate(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      accessibilityNeeds: data['accessibilityNeeds'] as String?,
      dietaryRequirements: data['dietaryRequirements'] as String?,
      addedAt: data['addedAt'] as String? ?? '',
    );
  }
}
