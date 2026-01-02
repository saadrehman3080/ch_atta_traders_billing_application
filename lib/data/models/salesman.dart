/// Model representing a salesman in the system.
class Salesman {
  final String id;
  final String name;
  final int password;
  final int salesmanId;

  Salesman({
    required this.id,
    required this.name,
    required this.password,
    required this.salesmanId,
  });

  /// Creates a [Salesman] instance from Firestore document data.
  factory Salesman.fromFirestore(String docId, Map<String, dynamic> data) {
    return Salesman(
      id: docId,
      name: data['name'] as String? ?? '',
      password: data['password'] as int? ?? 0,
      salesmanId: data['salesmanId'] as int? ?? 0,
    );
  }
}
