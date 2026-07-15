import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:hive/hive.dart';

part 'pending_bill.g.dart';

// ─── Status Enum ──────────────────────────────────────────────────────────────

@HiveType(typeId: 10)
enum PendingBillStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  syncing,

  @HiveField(2)
  failed,

  @HiveField(3)
  synced,
}

// ─── PendingBill Model ────────────────────────────────────────────────────────

@HiveType(typeId: 11)
class PendingBill extends HiveObject {
  @HiveField(0)
  final String billId;

  @HiveField(1)
  final String customerName;

  @HiveField(2)
  final DateTime date;

  /// Products serialised as plain JSON so we avoid registering complex
  /// type adapters for Product inside Hive.
  @HiveField(3)
  final List<Map<String, dynamic>> productsJson;

  @HiveField(4)
  final int discount;

  /// Firestore document path segment (e.g. salesman identifier / doc ID).
  @HiveField(5)
  final String salesmanIdentifier;

  /// 'sale' | 'credit'
  @HiveField(6)
  final String billType;

  @HiveField(7)
  final bool isPaid;

  @HiveField(8)
  final int amountDue;

  @HiveField(9)
  final int cratesDue;

  @HiveField(10)
  final List<Map<String, dynamic>> partialPaymentsJson;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final int syncAttempts;

  /// 'cash' | 'credit'
  @HiveField(13)
  final String? paymentType;

  @HiveField(14)
  final int schemaVersion;

  @HiveField(15)
  final PendingBillStatus status;

  @HiveField(16)
  final DateTime? lastSyncAttempt;

  @HiveField(17)
  final bool isReceiptGenerated;

  PendingBill({
    required this.billId,
    required this.customerName,
    required this.date,
    required this.productsJson,
    required this.discount,
    required this.salesmanIdentifier,
    required this.billType,
    required this.isPaid,
    required this.amountDue,
    required this.cratesDue,
    required this.partialPaymentsJson,
    required this.createdAt,
    this.syncAttempts = 0,
    this.paymentType,
    this.schemaVersion = 1,
    this.status = PendingBillStatus.pending,
    this.lastSyncAttempt,
    this.isReceiptGenerated = false,
  });

  // ─── Factory Constructors ─────────────────────────────────────────────────

  factory PendingBill.fromSaleHistory({
    required SaleHistory bill,
    required String salesmanIdentifier,
  }) {
    return PendingBill(
      billId: bill.billId,
      customerName: bill.customerName,
      date: bill.date,
      productsJson: bill.products.map((p) => p.toJson()).toList(),
      discount: bill.discount,
      salesmanIdentifier: salesmanIdentifier,
      billType: 'sale',
      isPaid: true,
      amountDue: 0,
      cratesDue: 0,
      partialPaymentsJson: const [],
      createdAt: DateTime.now(),
      paymentType: bill.billType.toJson(),
      isReceiptGenerated: bill.isReceiptGenerated,
    );
  }

  factory PendingBill.fromCreditHistory({
    required CreditHistory bill,
    required String salesmanIdentifier,
    String? paymentType,
  }) {
    return PendingBill(
      billId: bill.billId,
      customerName: bill.customerName,
      date: bill.date,
      productsJson: bill.products.map((p) => p.toJson()).toList(),
      discount: bill.discount,
      salesmanIdentifier: salesmanIdentifier,
      billType: 'credit',
      isPaid: bill.isPaid,
      amountDue: bill.amountDue,
      cratesDue: bill.cratesDue,
      partialPaymentsJson: bill.partialPayments.map((p) => p.toJson()).toList(),
      createdAt: DateTime.now(),
      paymentType: paymentType,
      isReceiptGenerated: bill.isReceiptGenerated,
    );
  }

  // ─── CopyWith (for status mutations) ─────────────────────────────────────

  PendingBill copyWith({
    int? syncAttempts,
    PendingBillStatus? status,
    DateTime? lastSyncAttempt,
    bool? isReceiptGenerated,
  }) {
    return PendingBill(
      billId: billId,
      customerName: customerName,
      date: date,
      productsJson: productsJson,
      discount: discount,
      salesmanIdentifier: salesmanIdentifier,
      billType: billType,
      isPaid: isPaid,
      amountDue: amountDue,
      cratesDue: cratesDue,
      partialPaymentsJson: partialPaymentsJson,
      createdAt: createdAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      paymentType: paymentType,
      schemaVersion: schemaVersion,
      status: status ?? this.status,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
      isReceiptGenerated: isReceiptGenerated ?? this.isReceiptGenerated,
    );
  }
}
