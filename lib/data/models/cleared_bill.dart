import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';

/// Represents a credit bill entry in the previous day collection.
/// Can be either a fully cleared bill or a partial payment received today.
///
/// Stored at: Cleared Bills/{salesmanName}/{todayDate}/bills/{billId}
class ClearedBill {
  /// Original bill ID
  final String billId;

  /// Customer name from the original bill
  final String customerName;

  /// Original bill date (the date when the credit was created)
  final DateTime originalDate;

  /// Date when the bill was cleared/payment received (today)
  final DateTime clearedDate;

  /// Amount that was still due and paid today to clear the bill
  final int amountPaidToday;

  /// Crates that were still due and returned today
  final int cratesReturnedToday;

  /// Original grand total of the bill (before discount)
  final int originalTotal;

  /// Discount applied on the original bill
  final int discount;

  /// Products from the original bill
  final List<Product> products;

  /// Whether the cash was already paid (bill was cash+MT tracking only)
  final bool wasCashAlreadyPaid;

  /// Partial payments that were made before the final clearing
  final List<PartialPayment> partialPayments;

  /// Whether this entry is a partial payment (not fully cleared)
  final bool isPartialPayment;

  /// For partial payments: the amount still remaining after this payment
  final int remainingAmountAfterPayment;

  /// For partial payments: the crates still remaining after this return
  final int remainingCratesAfterPayment;

  ClearedBill({
    required this.billId,
    required this.customerName,
    required this.originalDate,
    required this.clearedDate,
    required this.amountPaidToday,
    required this.cratesReturnedToday,
    required this.originalTotal,
    required this.discount,
    required this.products,
    this.wasCashAlreadyPaid = false,
    this.partialPayments = const [],
    this.isPartialPayment = false,
    this.remainingAmountAfterPayment = 0,
    this.remainingCratesAfterPayment = 0,
  });

  /// Net total after discount
  int get netTotal => originalTotal - discount;

  /// Total amount already paid via partial payments before clearing
  int get totalPreviouslyPaid =>
      partialPayments.fold(0, (sum, p) => sum + p.amount);

  /// Formatted original date
  String get formattedOriginalDate {
    return '${originalDate.day}-${originalDate.month}-${originalDate.year}';
  }

  /// Formatted cleared date
  String get formattedClearedDate {
    return '${clearedDate.day}-${clearedDate.month}-${clearedDate.year}';
  }

  /// Formatted cleared time
  String get formattedClearedTime {
    final hour = clearedDate.hour > 12
        ? clearedDate.hour - 12
        : (clearedDate.hour == 0 ? 12 : clearedDate.hour);
    final period = clearedDate.hour >= 12 ? 'PM' : 'AM';
    final minute = clearedDate.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'billId': billId,
      'customerName': customerName,
      'originalDate': originalDate.toIso8601String(),
      'clearedDate': clearedDate.toIso8601String(),
      'amountPaidToday': amountPaidToday,
      'cratesReturnedToday': cratesReturnedToday,
      'originalTotal': originalTotal,
      'discount': discount,
      'products': products.map((p) => p.toJson()).toList(),
      'wasCashAlreadyPaid': wasCashAlreadyPaid,
      'partialPayments': partialPayments.map((p) => p.toJson()).toList(),
      'isPartialPayment': isPartialPayment,
      'remainingAmountAfterPayment': remainingAmountAfterPayment,
      'remainingCratesAfterPayment': remainingCratesAfterPayment,
    };
  }

  /// Create from JSON (Firestore document)
  factory ClearedBill.fromJson(Map<String, dynamic> json) {
    return ClearedBill(
      billId: json['billId'] as String,
      customerName: json['customerName'] as String,
      originalDate: DateTime.parse(json['originalDate'] as String),
      clearedDate: DateTime.parse(json['clearedDate'] as String),
      amountPaidToday: json['amountPaidToday'] as int? ?? 0,
      cratesReturnedToday: json['cratesReturnedToday'] as int? ?? 0,
      originalTotal: json['originalTotal'] as int? ?? 0,
      discount: json['discount'] as int? ?? 0,
      products: json['products'] != null
          ? (json['products'] as List<dynamic>)
                .map((item) => Product.fromJson(item as Map<String, dynamic>))
                .toList()
          : [],
      wasCashAlreadyPaid: json['wasCashAlreadyPaid'] as bool? ?? false,
      partialPayments: json['partialPayments'] != null
          ? (json['partialPayments'] as List<dynamic>)
                .map(
                  (item) =>
                      PartialPayment.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : [],
      isPartialPayment: json['isPartialPayment'] as bool? ?? false,
      remainingAmountAfterPayment:
          json['remainingAmountAfterPayment'] as int? ?? 0,
      remainingCratesAfterPayment:
          json['remainingCratesAfterPayment'] as int? ?? 0,
    );
  }

  /// Create a ClearedBill from a CreditHistory that is being cleared today.
  factory ClearedBill.fromCreditHistory({
    required CreditHistory credit,
    required int amountPaidToday,
    required int cratesReturnedToday,
  }) {
    final grandTotal = credit.products.fold<int>(
      0,
      (sum, product) => sum + (product.price * product.quantity),
    );

    return ClearedBill(
      billId: credit.billId,
      customerName: credit.customerName,
      originalDate: credit.date,
      clearedDate: DateTime.now(),
      amountPaidToday: amountPaidToday,
      cratesReturnedToday: cratesReturnedToday,
      originalTotal: grandTotal,
      discount: credit.discount,
      products: credit.products,
      wasCashAlreadyPaid: credit.isPaid,
      partialPayments: credit.partialPayments,
    );
  }

  /// Create a ClearedBill entry for a partial payment received today.
  factory ClearedBill.fromPartialPayment({
    required CreditHistory credit,
    required int amountReceived,
    required int cratesReceived,
    required int remainingAmount,
    required int remainingCrates,
  }) {
    final grandTotal = credit.products.fold<int>(
      0,
      (sum, product) => sum + (product.price * product.quantity),
    );

    return ClearedBill(
      billId: credit.billId,
      customerName: credit.customerName,
      originalDate: credit.date,
      clearedDate: DateTime.now(),
      amountPaidToday: amountReceived,
      cratesReturnedToday: cratesReceived,
      originalTotal: grandTotal,
      discount: credit.discount,
      products: credit.products,
      wasCashAlreadyPaid: credit.isPaid,
      partialPayments: credit.partialPayments,
      isPartialPayment: true,
      remainingAmountAfterPayment: remainingAmount,
      remainingCratesAfterPayment: remainingCrates,
    );
  }
}
