/// Represents a single payment entry in a customer's bulk payment history.
class BulkPaymentEntry {
  final DateTime date;
  final int amount;

  /// Non-null when this entry represents a full bill completion.
  final String? billId;

  BulkPaymentEntry({required this.date, required this.amount, this.billId});

  factory BulkPaymentEntry.fromJson(Map<String, dynamic> json) {
    return BulkPaymentEntry(
      date: DateTime.parse(json['date'] as String),
      amount: json['amount'] as int,
      billId: json['billId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'amount': amount,
    if (billId != null) 'billId': billId,
  };
}

/// Snapshot of a bill that was individually marked as paid while bulk payment
/// tracking was active.
class CompletedBillInfo {
  final String billId;
  final int originalAmount;
  final DateTime billDate;
  final DateTime completedAt;

  CompletedBillInfo({
    required this.billId,
    required this.originalAmount,
    required this.billDate,
    required this.completedAt,
  });

  factory CompletedBillInfo.fromJson(Map<String, dynamic> json) {
    return CompletedBillInfo(
      billId: json['billId'] as String,
      originalAmount: json['originalAmount'] as int,
      billDate: DateTime.parse(json['billDate'] as String),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'billId': billId,
    'originalAmount': originalAmount,
    'billDate': billDate.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
  };
}

/// Stores bulk payment history for a customer who has multiple credit bills.
/// Payment is tracked at the customer level, NOT against individual bills.
/// Individual bills are only updated (marked paid) when the full amount is collected.
class CustomerBulkPayment {
  final String customerName;
  final List<BulkPaymentEntry> paymentHistory;

  /// Original amount due for each bill at the time of first payment.
  final Map<String, int> billAmounts;

  /// Bills that were individually marked as paid from the credit record page.
  final List<CompletedBillInfo> completedBills;
  final DateTime updatedAt;

  CustomerBulkPayment({
    required this.customerName,
    this.paymentHistory = const [],
    this.billAmounts = const {},
    this.completedBills = const [],
    required this.updatedAt,
  });

  /// Total amount collected so far across all payment entries.
  int get totalPaid => paymentHistory.fold(0, (sum, e) => sum + e.amount);

  factory CustomerBulkPayment.fromJson(Map<String, dynamic> json) {
    return CustomerBulkPayment(
      customerName: json['customerName'] as String,
      paymentHistory: json['paymentHistory'] != null
          ? (json['paymentHistory'] as List<dynamic>)
                .map(
                  (e) => BulkPaymentEntry.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : [],
      billAmounts: json['billAmounts'] != null
          ? Map<String, int>.from(json['billAmounts'] as Map)
          : {},
      completedBills: json['completedBills'] != null
          ? (json['completedBills'] as List<dynamic>)
                .map(
                  (e) => CompletedBillInfo.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : [],
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'customerName': customerName,
    'paymentHistory': paymentHistory.map((e) => e.toJson()).toList(),
    'billAmounts': billAmounts,
    'completedBills': completedBills.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  CustomerBulkPayment copyWith({
    String? customerName,
    List<BulkPaymentEntry>? paymentHistory,
    Map<String, int>? billAmounts,
    List<CompletedBillInfo>? completedBills,
    DateTime? updatedAt,
  }) {
    return CustomerBulkPayment(
      customerName: customerName ?? this.customerName,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      billAmounts: billAmounts ?? this.billAmounts,
      completedBills: completedBills ?? this.completedBills,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
