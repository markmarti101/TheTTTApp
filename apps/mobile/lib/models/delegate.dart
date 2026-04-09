class Delegate {
  final String id;
  final String name;
  final String email;
  final String addedAt;

  Delegate({
    required this.id,
    required this.name,
    required this.email,
    required this.addedAt,
  });

  factory Delegate.fromFirestore(String id, Map<String, dynamic> data) {
    return Delegate(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      addedAt: data['addedAt'] as String? ?? '',
    );
  }
}
