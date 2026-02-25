/// Represents a shop/outlet from the CHAUDHARY ATTA TRADERS shop database.
///
/// Contains essential details about each outlet including its code, name,
/// address, route assignment, owner info, and GPS coordinates.
class Shop {
  final String outletCode;
  final String outletName;
  final String outletAddress;
  final String town;
  final String routeTitle;
  final String owner;
  final String phone;
  final double? latitude;
  final double? longitude;

  const Shop({
    required this.outletCode,
    required this.outletName,
    required this.outletAddress,
    required this.town,
    required this.routeTitle,
    required this.owner,
    required this.phone,
    this.latitude,
    this.longitude,
  });

  /// Creates a [Shop] from a SQLite database row.
  factory Shop.fromMap(Map<String, dynamic> map) {
    final code = map['outlet_code'] as String?;
    assert(code != null && code.isNotEmpty, 'DB row missing outlet_code');
    return Shop(
      outletCode: code ?? '',
      outletName: map['outlet_name'] as String? ?? '',
      outletAddress: map['outlet_address'] as String? ?? '',
      town: map['town'] as String? ?? '',
      routeTitle: map['route_title'] as String? ?? '',
      owner: map['owner'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  /// Converts this [Shop] to a map for SQLite insertion.
  Map<String, dynamic> toMap() {
    return {
      'outlet_code': outletCode,
      'outlet_name': outletName,
      'outlet_address': outletAddress,
      'town': town,
      'route_title': routeTitle,
      'owner': owner,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Returns a user-friendly display name for the shop.
  String get displayName => outletName;

  /// Returns a formatted route number (e.g., "1", "2", "3" from "KALLAR SYEDAN-1").
  String get routeNumber {
    final parts = routeTitle.split('-');
    return parts.length > 1 ? parts.last.trim() : routeTitle;
  }

  @override
  String toString() => 'Shop($outletCode: $outletName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shop &&
          runtimeType == other.runtimeType &&
          outletCode == other.outletCode;

  @override
  int get hashCode => outletCode.hashCode;
}
