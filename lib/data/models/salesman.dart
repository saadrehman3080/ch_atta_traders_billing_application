/// Model representing a salesman in the system.
class Salesman {
  final String id;
  final String name;
  final int password;
  final int salesmanId;
  final bool isAdmin;
  final bool hasAccess;

  Salesman({
    required this.id,
    required this.name,
    required this.password,
    required this.salesmanId,
    this.isAdmin = false,
    this.hasAccess = true,
  });

  /// Creates a [Salesman] instance from Firestore document data.
  factory Salesman.fromFirestore(String docId, Map<String, dynamic> data) {
    return Salesman(
      id: docId,
      name: data['name'] as String? ?? '',
      password: data['password'] as int? ?? 0,
      salesmanId: data['salesmanId'] as int? ?? 0,
      isAdmin: data['isAdmin'] as bool? ?? false,
      hasAccess: data['hasAccess'] as bool? ?? true,
    );
  }
}
