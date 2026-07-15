import 'dart:async';

import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/offline_dashboard_payload.dart';
import 'package:ch_atta_traders_billing_application/data/models/pending_bill.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/features/checkout/providers/checkout_form_provider.dart';
import 'package:ch_atta_traders_billing_application/features/credit/providers/credit_provider.dart';
import 'package:ch_atta_traders_billing_application/features/sales/providers/sale_provider.dart';
import 'package:ch_atta_traders_billing_application/services/offline/offline_bill_service.dart';
import 'package:ch_atta_traders_billing_application/services/offline/offline_dashboard_queue_service.dart';
import 'package:ch_atta_traders_billing_application/services/offline/offline_bill_sync_manager.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_connection_service.dart';
import 'package:flutter/material.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/services/printer/bill_printer.dart';
import 'package:ch_atta_traders_billing_application/features/checkout/presentation/pages/shop_selection_page.dart';

class CheckoutPage extends StatefulWidget {
  final List<Product> products;
  final CheckoutFormProvider formProvider;
  final VoidCallback onPrint;
  final VoidCallback onDismiss;

  const CheckoutPage({
    super.key,
    required this.products,
    required this.formProvider,
    required this.onPrint,
    required this.onDismiss,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final SaleProvider _saleProvider;
  late final CreditProvider _creditProvider;
  final _uuid = const Uuid();

  bool _isPrinterConnected = true; // Default to true, will be updated on check
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _mtController = TextEditingController();
  final TextEditingController _partialPaymentController =
      TextEditingController();
  bool _isScrollable = false;
  String _paymentType = 'cash';
  int _discount = 0;
  int _mt = 0;
  int _partialPayment = 0;
  bool _isSaving = false;
  bool _isPrinting = false;
  bool _isAnonymousCustomer = false; // When true, skip customer name on bill
  bool _completedSuccessfully =
      false; // Prevents dispose from overwriting reset

  @override
  void initState() {
    super.initState();
    _saleProvider = SaleProvider();
    _creditProvider = CreditProvider();

    // Restore state from provider if it was previously opened
    final fp = widget.formProvider;
    if (fp.hasBeenOpened) {
      _customerNameController.text = fp.customerName;
      _paymentType = fp.paymentType;
      _discount = fp.discount;
      _mt = fp.mt;
      _partialPayment = fp.partialPayment;
      _isAnonymousCustomer = fp.isAnonymousCustomer;
      if (fp.discount > 0) _discountController.text = '${fp.discount}';
      if (fp.mt > 0) _mtController.text = '${fp.mt}';
      if (fp.partialPayment > 0) {
        _partialPaymentController.text = '${fp.partialPayment}';
      }
    }

    _customerNameController.addListener(_updateButtonState);
    _discountController.addListener(_updateDiscount);
    _mtController.addListener(_updateMt);
    _partialPaymentController.addListener(_updatePartialPayment);
    _scrollController.addListener(_checkScrollable);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollable());
    _checkPrinterConnection();
    _loadSkipCustomerNamePreference(isFirstOpen: !fp.hasBeenOpened);
    fp.markOpened();
    // Listen to printer connection changes
    PrinterConnectionService.instance.addListener(_onPrinterConnectionChanged);
  }

  /// Called when printer connection status changes
  void _onPrinterConnectionChanged() {
    if (mounted) {
      setState(() {
        _isPrinterConnected = PrinterConnectionService.instance.isConnected;
      });
    }
  }

  /// Check printer connection status using centralized service
  Future<void> _checkPrinterConnection() async {
    final isConnected = await PrinterConnectionService.instance
        .checkConnection();
    if (mounted) {
      setState(() => _isPrinterConnected = isConnected);
    }
  }

  /// Load skip customer name preference and apply it.
  ///
  /// [isFirstOpen] controls whether the MT auto-fill runs; it should only
  /// run on a genuinely fresh checkout, not when restoring a dismissed one.
  /// The anonymous-customer toggle is always applied so the dashboard
  /// preference is consistently respected every time checkout opens.
  Future<void> _loadSkipCustomerNamePreference({
    bool isFirstOpen = true,
  }) async {
    final skipByDefault =
        await AppPreferences.instance.isSkipCustomerNameDefault;
    if (skipByDefault && _paymentType != 'credit' && mounted) {
      setState(() {
        _isAnonymousCustomer = true;
        if (isFirstOpen && _hasRbProducts) {
          final totalRb = _getTotalRbQuantity();
          _mtController.text = '$totalRb';
          _mt = totalRb;
        }
      });
    }
  }

  @override
  void dispose() {
    // Sync current form values back to the provider so they survive dismiss,
    // but skip if the sale completed successfully (provider was already reset).
    if (!_completedSuccessfully) {
      widget.formProvider.saveState(
        customerName: _customerNameController.text.trim(),
        paymentType: _paymentType,
        discount: _discount,
        mt: _mt,
        partialPayment: _partialPayment,
        isAnonymousCustomer: _isAnonymousCustomer,
      );
    }

    _customerNameController.removeListener(_updateButtonState);
    _discountController.removeListener(_updateDiscount);
    _mtController.removeListener(_updateMt);
    _partialPaymentController.removeListener(_updatePartialPayment);
    _scrollController.removeListener(_checkScrollable);
    _scrollController.dispose();
    _customerNameController.dispose();
    _discountController.dispose();
    _mtController.dispose();
    _partialPaymentController.dispose();
    _saleProvider.dispose();
    _creditProvider.dispose();
    PrinterConnectionService.instance.removeListener(
      _onPrinterConnectionChanged,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _saleProvider),
        ChangeNotifierProvider.value(value: _creditProvider),
      ],
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: _buildContainerDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            _buildSummaryInfo(),
            const SizedBox(height: 12),
            _buildScrollableContent(),
          ],
        ),
      ),
    );
  }

  // ========== Business Logic Methods ==========

  void _updateButtonState() {
    setState(() {});
  }

  void _updateDiscount() {
    final text = _discountController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _discount = 0;
      });
      return;
    }

    final value = int.tryParse(text) ?? 0;
    final grandTotalBeforeDiscount = BillingCalculations.calculateGrandTotal(
      widget.products,
    );

    if (value < 0 || value > grandTotalBeforeDiscount) {
      _discountController.text = '0';
      _discountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _discountController.text.length),
      );
      setState(() {
        _discount = 0;
      });
    } else {
      setState(() {
        _discount = value;
      });
    }
  }

  void _updateMt() {
    final text = _mtController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _mt = 0;
      });
      return;
    }

    final value = int.tryParse(text) ?? 0;
    final totalRbQuantity = _getTotalRbQuantity();

    if (value < 0 || value > totalRbQuantity) {
      _mtController.text = '0';
      _mtController.selection = TextSelection.fromPosition(
        TextPosition(offset: _mtController.text.length),
      );
      setState(() {
        _mt = 0;
      });
    } else {
      setState(() {
        _mt = value;
      });
    }
  }

  void _updatePartialPayment() {
    final text = _partialPaymentController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _partialPayment = 0;
      });
      return;
    }

    final value = int.tryParse(text) ?? 0;

    if (value < 0 || value >= _grandTotal) {
      _partialPaymentController.text = '0';
      _partialPaymentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _partialPaymentController.text.length),
      );
      setState(() {
        _partialPayment = 0;
      });
    } else {
      setState(() {
        _partialPayment = value;
      });
    }
  }

  void _checkScrollable() {
    if (_scrollController.hasClients) {
      final isScrollable = _scrollController.position.maxScrollExtent > 0;
      if (isScrollable != _isScrollable) {
        setState(() {
          _isScrollable = isScrollable;
        });
      }
    }
  }

  int get _selectedProductsCount {
    return BillingCalculations.countSelectedProducts(widget.products);
  }

  int get _selectedItemsCount {
    return BillingCalculations.calculateTotalItems(widget.products);
  }

  List<Product> get _selectedProducts {
    return BillingCalculations.getSelectedProducts(widget.products);
  }

  int get _grandTotal {
    final total = BillingCalculations.calculateGrandTotal(widget.products);
    return total - _discount;
  }

  bool get _hasEnteredCustomerName {
    return _customerNameController.text.trim().isNotEmpty;
  }

  bool get _requiresNamedCustomer {
    return !_shouldSaveToDailySales();
  }

  bool get _hasValidCustomerForCurrentBill {
    if (_requiresNamedCustomer) {
      return _hasEnteredCustomerName;
    }
    return _hasEnteredCustomerName || _isAnonymousCustomer;
  }

  bool get _hasRbProducts {
    return _selectedProducts.any(
      (product) => product.name.toUpperCase().endsWith('RB'),
    );
  }

  int _getTotalRbQuantity() {
    return _selectedProducts
        .where((product) => product.name.toUpperCase().endsWith('RB'))
        .fold(0, (sum, product) => sum + product.quantity);
  }

  /// Determines the customer name for database and display
  /// Returns 'Walk-In Customer' if anonymous, otherwise the entered name
  String _getCustomerName() {
    final enteredName = _customerNameController.text.trim();
    return _isAnonymousCustomer ? 'Walk-In Customer' : enteredName;
  }

  /// Determines whether bill should go to Daily Sales (true) or Credit History (false)
  ///
  /// Business Logic:
  /// - Daily Sales: Cash payment AND (no MT tracking OR all MT collected)
  ///   - Fully completed transactions
  /// - Credit History: All other cases that need tracking:
  ///   - Credit payment (money pending)
  ///   - Cash payment with MT pending (crates pending return)
  bool _shouldSaveToDailySales() {
    if (_paymentType != 'cash') {
      return false; // Credit payments always go to Credit History
    }

    final hasMt = _mtController.text.trim().isNotEmpty;
    if (!hasMt) {
      return true; // No MT tracking = completed sale
    }

    // If MT is entered, check if all crates were collected
    final totalRbQuantity = _getTotalRbQuantity();
    final cratesDue = totalRbQuantity - _mt;
    return cratesDue == 0; // All crates collected = completed sale
  }

  /// Creates bill data for saving to Firestore
  /// Returns either SaleHistory or CreditHistory based on business rules
  dynamic _prepareBillData(String billId, {required bool isReceiptGenerated}) {
    final customerName = _getCustomerName();
    final products = _selectedProducts
        .map(
          (p) => Product(
            name: p.name,
            price: p.price,
            quantity: p.quantity,
            type: p.type,
            subtypes: p.subtypes,
            subtypeQuantities: Map.from(p.subtypeQuantities),
          ),
        )
        .toList();

    if (_shouldSaveToDailySales()) {
      // Fully completed cash sale - no tracking needed
      return SaleHistory(
        billId: billId,
        customerName: customerName,
        date: DateTime.now(),
        products: products,
        discount: _discount,
        isReceiptGenerated: isReceiptGenerated,
        billType: BillType.cash,
      );
    } else {
      // Needs tracking (credit payment or MT pending)
      final hasMt = _mtController.text.trim().isNotEmpty;
      final totalRbQuantity = _getTotalRbQuantity();
      final cratesDue = hasMt ? (totalRbQuantity - _mt) : 0;

      // Handle partial payment for credit
      final hasPartialPayment = _paymentType == 'credit' && _partialPayment > 0;
      final amountDue = hasPartialPayment
          ? (_grandTotal - _partialPayment)
          : _grandTotal;
      final List<PartialPayment> partialPayments = hasPartialPayment
          ? [PartialPayment(date: DateTime.now(), amount: _partialPayment)]
          : [];

      return CreditHistory(
        billId: billId,
        customerName: customerName,
        date: DateTime.now(),
        products: products,
        discount: _discount,
        isReceiptGenerated: isReceiptGenerated,
        isPaid:
            _paymentType ==
            'cash', // True if cash (only MT pending), false if credit
        amountDue: amountDue,
        cratesDue: cratesDue,
        billType: BillType.credit,
        partialPayments: partialPayments,
      );
    }
  }

  /// Validates checkout inputs before saving/printing
  /// Returns error message if invalid, null if valid
  String? _validateCheckout() {
    // Any bill saved to credit history must have a real customer name.
    // This includes both explicit credit payments and cash bills with MT due.
    if (_requiresNamedCustomer) {
      if (_isAnonymousCustomer) {
        return 'Customer name required for credit and MT remaining bills';
      }
      if (!_hasEnteredCustomerName) {
        return 'Please enter customer name for credit and MT remaining bills';
      }
    } else if (!_hasEnteredCustomerName && !_isAnonymousCustomer) {
      return 'Please enter customer name or select anonymous';
    }

    // Validate products selected
    if (_selectedProducts.isEmpty) {
      return 'No products selected';
    }

    // Validate grand total
    if (_grandTotal <= 0) {
      return 'Total amount must be greater than zero';
    }

    // Validate MT if entered
    if (_mtController.text.trim().isNotEmpty) {
      final totalRbQuantity = _getTotalRbQuantity();
      if (_mt > totalRbQuantity) {
        return 'Collected MT cannot exceed total RB quantity';
      }
    }

    return null; // All valid
  }

  /// Saves bill to local Hive store first (offline-first).
  /// Returns the [PendingBill] so the caller can trigger a background sync
  /// after printing.
  Future<PendingBill> _saveBillOfflineFirst({
    required String billId,
    required String salesmanIdentifier,
    required bool isReceiptGenerated,
  }) async {
    final billData = _prepareBillData(
      billId,
      isReceiptGenerated: isReceiptGenerated,
    );
    final PendingBill pendingBill;

    if (billData is SaleHistory) {
      pendingBill = PendingBill.fromSaleHistory(
        bill: billData,
        salesmanIdentifier: salesmanIdentifier,
      );
    } else {
      pendingBill = PendingBill.fromCreditHistory(
        bill: billData as CreditHistory,
        salesmanIdentifier: salesmanIdentifier,
        paymentType: _paymentType,
      );
    }

    await OfflineBillService().savePendingBill(pendingBill);
    final dashboardPayload = _buildDashboardPayload(pendingBill);
    await OfflineDashboardQueueService().savePayload(dashboardPayload);
    return pendingBill;
  }

  OfflineDashboardPayload _buildDashboardPayload(PendingBill pendingBill) {
    final itemsSold = pendingBill.productsJson.fold<int>(
      0,
      (sum, p) => sum + ((p['quantity'] as num?)?.toInt() ?? 0),
    );

    final grossTotal = pendingBill.productsJson.fold<int>(0, (sum, p) {
      final price = (p['price'] as num?)?.toInt() ?? 0;
      final quantity = (p['quantity'] as num?)?.toInt() ?? 0;
      return sum + (price * quantity);
    });

    final totalAmount = (grossTotal - pendingBill.discount).clamp(0, 1 << 31);

    int totalCollectionDelta = 0;
    int totalCreditDelta = 0;

    if (pendingBill.billType == 'sale') {
      totalCollectionDelta = totalAmount;
    } else if (pendingBill.isPaid) {
      totalCollectionDelta = pendingBill.amountDue;
    } else {
      totalCreditDelta = pendingBill.amountDue;
      final partialPaymentTotal = pendingBill.partialPaymentsJson.fold<int>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toInt() ?? 0),
      );
      totalCollectionDelta = partialPaymentTotal;
    }

    return OfflineDashboardPayload(
      billId: pendingBill.billId,
      salesmanIdentifier: pendingBill.salesmanIdentifier,
      date: pendingBill.date,
      totalCollectionDelta: totalCollectionDelta,
      totalItemsSoldDelta: itemsSold,
      totalMtRemainingDelta: pendingBill.billType == 'credit'
          ? pendingBill.cratesDue
          : 0,
      totalCreditDelta: totalCreditDelta,
      totalDiscountDelta: pendingBill.discount,
      customersServedDelta: 1,
      createdAt: DateTime.now(),
    );
  }

  Future<void> _printBill({
    required String billId,
    required String customerName,
    required DateTime date,
    required List<Product> products,
    required int discount,
    required String salesmanName,
    required String paymentType,
    int? mtCollected,
    int? mtRemaining,
    int? partialPayment,
    bool showDuplicateLabel = false,
    bool includeSubtypeDetails = false,
    bool isPendingSync = false,
  }) async {
    final result = await BillPrinter.printBill(
      billId: billId,
      customerName: customerName,
      date: date,
      products: products,
      discount: discount,
      salesmanName: salesmanName,
      paymentType: paymentType,
      mtCollected: mtCollected,
      mtRemaining: mtRemaining,
      partialPayment: partialPayment,
      showDuplicateLabel: showDuplicateLabel,
      includeSubtypeDetails: includeSubtypeDetails,
      isPendingSync: isPendingSync,
    );

    if (mounted) {
      if (result.success) {
        CustomSnackBar.show(
          context,
          message: 'Bill saved & printed successfully',
          type: SnackBarType.success,
        );
      } else {
        CustomSnackBar.show(
          context,
          message:
              'Bill saved but print failed: ${result.errorMessage ?? 'Unknown error'}',
          type: SnackBarType.warning,
        );
      }
    }
  }

  Future<void> _handleSaveBill() async {
    final validationError = _validateCheckout();
    if (validationError != null) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: validationError,
          type: SnackBarType.error,
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final salesmanIdentifier =
          await AppPreferences.instance.salesmanIdentifier;
      if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Salesman info not found. Please login again.',
            type: SnackBarType.error,
          );
        }
        return;
      }

      final billId = _uuid.v4();

      // Save locally first — instant, no network wait.
      final pendingBill = await _saveBillOfflineFirst(
        billId: billId,
        salesmanIdentifier: salesmanIdentifier,
        isReceiptGenerated: false,
      );

      // Fire background sync — do not await.
      unawaited(OfflineBillSyncManager.syncBill(pendingBill));

      if (mounted) {
        final billType = _shouldSaveToDailySales() ? 'Bill' : 'Credit';
        CustomSnackBar.show(
          context,
          message: '$billType saved successfully',
          type: SnackBarType.success,
        );
        _completedSuccessfully = true;
        widget.onPrint();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handlePrintBill() async {
    final validationError = _validateCheckout();
    if (validationError != null) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: validationError,
          type: SnackBarType.error,
        );
      }
      return;
    }

    if (!_isPrinterConnected) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Printer not connected. Please connect printer first.',
          type: SnackBarType.error,
        );
      }
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final salesmanName = await AppPreferences.instance.salesmanName;
      final salesmanIdentifier =
          await AppPreferences.instance.salesmanIdentifier;
      if (salesmanName == null ||
          salesmanName.isEmpty ||
          salesmanIdentifier == null ||
          salesmanIdentifier.isEmpty) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Salesman info not found. Please login again.',
            type: SnackBarType.error,
          );
        }
        return;
      }

      bool includeSubtypeDetails = false;
      final hasSubtypeProducts = _selectedProducts.any(
        (p) => p.hasSubtypes && p.subtypeQuantities.values.any((q) => q > 0),
      );
      if (hasSubtypeProducts && mounted) {
        final result = await _showSubtypeDetailDialog();
        if (result == null) return; // user cancelled
        includeSubtypeDetails = result;
      }

      final billId = _uuid.v4();

      // Save locally first — instant, no network wait.
      final pendingBill = await _saveBillOfflineFirst(
        billId: billId,
        salesmanIdentifier: salesmanIdentifier,
        isReceiptGenerated: true,
      );

      // Print immediately after local save.
      await _printBill(
        billId: billId,
        customerName: _getCustomerName(),
        date: DateTime.now(),
        products: _selectedProducts,
        discount: _discount,
        salesmanName: salesmanName,
        paymentType: _paymentType,
        mtCollected: _mtController.text.trim().isNotEmpty ? _mt : null,
        mtRemaining: _mtController.text.trim().isNotEmpty
            ? (_getTotalRbQuantity() - _mt)
            : null,
        partialPayment: _paymentType == 'credit' && _partialPayment > 0
            ? _partialPayment
            : null,
        showDuplicateLabel: false,
        includeSubtypeDetails: includeSubtypeDetails,
        isPendingSync: true,
      );

      // Fire background sync — do not await.
      unawaited(OfflineBillSyncManager.syncBill(pendingBill));

      if (mounted) {
        _completedSuccessfully = true;
        widget.onPrint();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  // ========== Main Container Building Methods ==========

  /// Shows a dialog asking the user whether to include subtype/variant details
  /// on the printed receipt. Returns true/false, or null if dismissed.
  Future<bool?> _showSubtypeDetailDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.pepsiWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long, color: AppColors.pepsiBlue, size: 40),
              const SizedBox(height: 16),
              Text(
                'Print Details',
                style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Include product variant details\n(e.g. Pepsi, 7UP, Dew) on the receipt?',
                textAlign: TextAlign.center,
                style: AppTextStyles.helperText.copyWith(
                  color: AppColors.gray500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.gray300.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'No',
                          style: AppTextStyles.smallButton.copyWith(
                            color: AppColors.gray500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pepsiBlue,
                          foregroundColor: AppColors.pepsiWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Yes',
                          style: AppTextStyles.smallButton.copyWith(
                            color: AppColors.pepsiWhite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildContainerDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.gray300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildScrollableContent() {
    return Flexible(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProductsList(),
            const SizedBox(height: 10),
            _buildPaymentTypeSelector(),
            const SizedBox(height: 10),
            _buildCustomerNameField(),
            const SizedBox(height: 10),
            _buildDiscountField(),
            if (_paymentType == 'credit') ...[
              const SizedBox(height: 10),
              _buildPartialPaymentField(),
            ],
            if (_hasRbProducts) ...[
              const SizedBox(height: 10),
              _buildMtField(),
            ],
            const SizedBox(height: 14),
            _buildPrintButton(),
          ],
        ),
      ),
    );
  }

  // ========== Summary Section Building Methods ==========

  Widget _buildSummaryInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _buildSummaryDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTotalAmountSection(),
          _buildTotalItemsProductsSection(),
        ],
      ),
    );
  }

  BoxDecoration _buildSummaryDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.pepsiBlue.withValues(alpha: 0.06),
          AppColors.pepsiBlueLight.withValues(alpha: 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.pepsiBlue.withValues(alpha: 0.15)),
    );
  }

  Widget _buildTotalAmountSection() {
    final totalRbQuantity = _getTotalRbQuantity();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Total Amount",
          style: AppTextStyles.billingItems.copyWith(
            color: Colors.black54,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "Rs. ${formatCashAmount(_grandTotal)}",
          style: AppTextStyles.billingTotal.copyWith(
            color: AppColors.pepsiBlue,
            fontSize: 24,
          ),
        ),
        if (totalRbQuantity > 0) ...[
          const SizedBox(height: 4),
          Text(
            "Remaining MT: ${totalRbQuantity - _mt}",
            style: AppTextStyles.billingItems.copyWith(
              color: AppColors.pepsiBlue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTotalItemsProductsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.pepsiBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            "$_selectedItemsCount items",
            style: AppTextStyles.billingItems.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "$_selectedProductsCount Products",
            style: AppTextStyles.billingItems.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Products List Building Methods ==========

  Widget _buildProductsList() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray300.withValues(alpha: 0.5)),
        ),
        child: Stack(
          children: [
            _buildProductsListView(),
            if (_isScrollable) _buildScrollIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsListView() {
    return ListView.separated(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: _selectedProducts.length,
      separatorBuilder: (context, index) =>
          const Divider(color: AppColors.gray300, height: 16),
      itemBuilder: (context, index) {
        return _buildProductListItem(_selectedProducts[index]);
      },
    );
  }

  Widget _buildProductListItem(Product product) {
    final itemTotal = product.price * product.quantity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              _buildProductName(product.name),
              const SizedBox(width: 8),
              _buildQuantityBadge(product.quantity),
              const SizedBox(width: 8),
              _buildItemTotal(itemTotal),
            ],
          ),
        ),
        if (product.hasSubtypes &&
            product.subtypeQuantities.values.any((q) => q > 0))
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Text(
              product.subtypeQuantities.entries
                  .where((e) => e.value > 0)
                  .map((e) => '${e.key}(${e.value})')
                  .join(', '),
              style: AppTextStyles.billingItems.copyWith(
                fontSize: 11,
                color: AppColors.gray500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductName(String name) {
    return Expanded(
      flex: 3,
      child: Text(
        name,
        style: AppTextStyles.productItemName.copyWith(fontSize: 13),
      ),
    );
  }

  Widget _buildQuantityBadge(int quantity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'x$quantity',
        style: AppTextStyles.productItemQuantity.copyWith(fontSize: 11),
      ),
    );
  }

  Widget _buildItemTotal(int total) {
    return Expanded(
      flex: 2,
      child: Text(
        'Rs. ${formatCashAmount(total)}',
        textAlign: TextAlign.right,
        style: AppTextStyles.productItemTotal.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildScrollIndicator() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.pepsiBlue,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  // ========== Form Building Methods ==========

  Widget _buildPaymentTypeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: _buildPaymentSegments(),
        selected: {_paymentType},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _paymentType = newSelection.first;
            // Reset anonymous customer if switching to credit
            if (_paymentType == 'credit') {
              _isAnonymousCustomer = false;
            }
            // Reset partial payment when switching payment type
            if (_paymentType != 'credit') {
              _partialPaymentController.clear();
              _partialPayment = 0;
            }
          });
        },
        style: _buildSegmentedButtonStyle(),
      ),
    );
  }

  List<ButtonSegment<String>> _buildPaymentSegments() {
    return const [
      ButtonSegment<String>(
        value: 'cash',
        label: Text('Cash'),
        icon: Icon(Icons.payments, size: 18),
      ),
      ButtonSegment<String>(
        value: 'credit',
        label: Text('Credit'),
        icon: Icon(Icons.account_balance, size: 18),
      ),
    ];
  }

  ButtonStyle _buildSegmentedButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.pepsiBlue;
        }
        return Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return Colors.black87;
      }),
      side: WidgetStateProperty.all(
        const BorderSide(color: AppColors.gray300, width: 1),
      ),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 6)),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  /// Opens the shop selection page and fills in customer name on selection.
  Future<void> _openShopSelection() async {
    final selectedShop = await Navigator.of(context).push<dynamic>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ShopSelectionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (selectedShop != null && mounted) {
      setState(() {
        _customerNameController.text = selectedShop.outletName;
        _isAnonymousCustomer = false;
      });
    }
  }

  Widget _buildCustomerNameField() {
    return Row(
      children: [
        Expanded(
          child: AbsorbPointer(
            absorbing: _isAnonymousCustomer,
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: const TextSelectionThemeData(
                  selectionHandleColor: AppColors.pepsiBlueLight,
                  selectionColor: AppColors.textSecondary,
                  cursorColor: AppColors.pepsiBlueLight,
                ),
              ),
              child: TextField(
                controller: _customerNameController,
                style: AppTextStyles.inputText.copyWith(
                  color: Colors.black87,
                  fontSize: 14,
                ),
                cursorColor: AppColors.pepsiBlue,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) {
                  FocusScope.of(context).unfocus();
                },
                decoration: _buildCustomerFieldDecoration(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildShopSelectionButton(),
        const SizedBox(width: 8),
        _buildAnonymousToggle(),
      ],
    );
  }

  Widget _buildShopSelectionButton() {
    return Tooltip(
      message: 'Select from shops',
      child: InkWell(
        onTap: _isAnonymousCustomer ? null : _openShopSelection,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _isAnonymousCustomer ? AppColors.gray100 : AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isAnonymousCustomer
                  ? AppColors.gray300.withValues(alpha: 0.5)
                  : AppColors.pepsiBlue.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            Icons.store_outlined,
            size: 22,
            color: _isAnonymousCustomer
                ? AppColors.gray400
                : AppColors.pepsiBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildAnonymousToggle() {
    // Disable anonymous customer for credit payments (need customer name for tracking)
    final isDisabled = _paymentType == 'credit';

    return Tooltip(
      message: isDisabled
          ? 'Customer name required for credit'
          : 'Skip Customer Name',
      child: InkWell(
        onTap: isDisabled
            ? null
            : () {
                final wasAnonymous = _isAnonymousCustomer;
                final previousMtText = _mtController.text.trim();
                final hadPreviousMt = previousMtText.isNotEmpty;
                setState(() {
                  _isAnonymousCustomer = !_isAnonymousCustomer;
                  // Clear focus and text when toggling anonymous customer ON
                  if (_isAnonymousCustomer) {
                    FocusScope.of(context).unfocus();
                    _customerNameController.clear();
                    // Keep already-entered MT so "returned" mode shows previous value.
                    if (hadPreviousMt) {
                      _mtController.text = previousMtText;
                      _mt = int.tryParse(previousMtText) ?? 0;
                    } else if (_hasRbProducts) {
                      // Match dashboard default-skip behavior on manual toggle.
                      final totalRb = _getTotalRbQuantity();
                      _mtController.text = '$totalRb';
                      _mtController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _mtController.text.length),
                      );
                      _mt = totalRb;
                    }
                  } else if (wasAnonymous) {
                    // Reset MT when switching back to named customer mode.
                    _mtController.clear();
                    _mt = 0;
                  }
                });
              },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDisabled
                ? AppColors.gray100
                : (_isAnonymousCustomer
                      ? AppColors.pepsiBlue
                      : AppColors.gray50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled
                  ? AppColors.gray300.withValues(alpha: 0.5)
                  : (_isAnonymousCustomer
                        ? AppColors.pepsiBlue
                        : AppColors.gray300.withValues(alpha: 0.5)),
            ),
          ),
          child: Icon(
            _isAnonymousCustomer ? Icons.person_off : Icons.person_off_outlined,
            size: 22,
            color: isDisabled
                ? AppColors.gray400
                : (_isAnonymousCustomer ? Colors.white : AppColors.gray500),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildCustomerFieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.gray50,
      labelText: "Customer Name",
      labelStyle: AppTextStyles.inputHint.copyWith(
        fontSize: 14,
        color: AppColors.gray400,
      ),
      floatingLabelStyle: AppTextStyles.inputHint.copyWith(
        fontSize: 14,
        color: AppColors.pepsiBlue,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: const Icon(
        Icons.person_outline,
        size: 20,
        color: AppColors.gray500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gray300.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.pepsiBlue, width: 1.5),
      ),
    );
  }

  Widget _buildDiscountField() {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          selectionHandleColor: AppColors.pepsiBlueLight,
          selectionColor: AppColors.textSecondary,
          cursorColor: AppColors.pepsiBlueLight,
        ),
      ),
      child: TextField(
        controller: _discountController,
        style: AppTextStyles.inputText.copyWith(
          color: Colors.black87,
          fontSize: 14,
        ),
        cursorColor: AppColors.pepsiBlue,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) {
          FocusScope.of(context).unfocus();
        },
        decoration: _buildDiscountFieldDecoration(),
      ),
    );
  }

  InputDecoration _buildDiscountFieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.gray50,
      labelText: "Discount",
      labelStyle: AppTextStyles.inputHint.copyWith(
        fontSize: 14,
        color: AppColors.gray400,
      ),
      floatingLabelStyle: AppTextStyles.inputHint.copyWith(
        fontSize: 14,
        color: AppColors.pepsiBlue,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: const Icon(
        Icons.discount_outlined,
        size: 20,
        color: AppColors.gray500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gray300.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.pepsiBlue, width: 1.5),
      ),
    );
  }

  Widget _buildMtField() {
    return AbsorbPointer(
      absorbing: _isAnonymousCustomer,
      child: Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionHandleColor: AppColors.pepsiBlueLight,
            selectionColor: AppColors.textSecondary,
            cursorColor: AppColors.pepsiBlueLight,
          ),
        ),
        child: TextField(
          controller: _mtController,
          style: AppTextStyles.inputText.copyWith(
            color: _isAnonymousCustomer ? AppColors.gray400 : Colors.black87,
            fontSize: 14,
          ),
          cursorColor: AppColors.pepsiBlue,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            FocusScope.of(context).unfocus();
          },
          decoration: _buildMtFieldDecoration(),
        ),
      ),
    );
  }

  InputDecoration _buildMtFieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: _isAnonymousCustomer ? AppColors.gray100 : AppColors.gray50,
      labelText: _isAnonymousCustomer
          ? "Total Empty Crates Returned"
          : "Collected MT",
      labelStyle: AppTextStyles.inputHint.copyWith(
        fontSize: 14,
        color: _isAnonymousCustomer ? AppColors.gray500 : AppColors.gray400,
      ),
      floatingLabelStyle: AppTextStyles.inputHint.copyWith(
        fontSize: 16,
        color: AppColors.pepsiBlue,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: Icon(
        Icons.inventory_2_outlined,
        size: 20,
        color: _isAnonymousCustomer ? AppColors.gray400 : AppColors.gray500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gray300.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.pepsiBlue, width: 1.5),
      ),
    );
  }

  Widget _buildPartialPaymentField() {
    final remaining = _grandTotal - _partialPayment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: const TextSelectionThemeData(
              selectionHandleColor: AppColors.pepsiBlueLight,
              selectionColor: AppColors.textSecondary,
              cursorColor: AppColors.pepsiBlueLight,
            ),
          ),
          child: TextField(
            controller: _partialPaymentController,
            style: AppTextStyles.inputText.copyWith(
              color: Colors.black87,
              fontSize: 14,
            ),
            cursorColor: AppColors.pepsiBlue,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              FocusScope.of(context).unfocus();
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.gray50,
              labelText: "Partial Payment Received",
              labelStyle: AppTextStyles.inputHint.copyWith(
                fontSize: 14,
                color: AppColors.gray400,
              ),
              floatingLabelStyle: AppTextStyles.inputHint.copyWith(
                fontSize: 14,
                color: AppColors.pepsiBlue,
                fontWeight: FontWeight.w500,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              prefixIcon: const Icon(
                Icons.payments_outlined,
                size: 20,
                color: AppColors.gray500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.gray300.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.pepsiBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (_partialPayment > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pepsiBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.pepsiBlue.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.pepsiBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total: Rs. ${formatCashAmount(_grandTotal)} - Paid: Rs. ${formatCashAmount(_partialPayment)} = Remaining: Rs. ${formatCashAmount(remaining)}',
                    style: AppTextStyles.helperText.copyWith(
                      fontSize: 12,
                      color: AppColors.pepsiBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrintButton() {
    return Consumer2<SaleProvider, CreditProvider>(
      builder: (context, saleProvider, creditProvider, child) {
        final isLoading = saleProvider.isSaving || creditProvider.isSaving;
        final isSaved =
            saleProvider.state == SaleState.saved ||
            creditProvider.state == CreditState.saved;
        final hasValidCustomer = _hasValidCustomerForCurrentBill;
        final canPrint =
            hasValidCustomer &&
            !isLoading &&
            !_isSaving &&
            !_isPrinting &&
            _isPrinterConnected;
        final canSave =
            hasValidCustomer && !isLoading && !_isSaving && !_isPrinting;

        return Row(
          children: [
            Expanded(
              flex: 85,
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: canPrint
                      ? () async {
                          FocusScope.of(context).unfocus();
                          await _handlePrintBill();
                          if (mounted && isSaved) {
                            _customerNameController.clear();
                            _discountController.clear();
                            _mtController.clear();
                            _partialPaymentController.clear();
                          }
                        }
                      : null,
                  icon: _isPrinting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.pepsiBlueLight.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        )
                      : Icon(
                          _isPrinterConnected
                              ? Icons.print
                              : Icons.print_disabled,
                          size: 20,
                        ),
                  label: Text(
                    _isPrinting
                        ? 'Saving & Printing...'
                        : (!_isPrinterConnected
                              ? "Printer Not Connected"
                              : "Print Bill"),
                    style: AppTextStyles.smallButton.copyWith(
                      color: canPrint ? Colors.white : AppColors.gray500,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: _buildPrintButtonStyle(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 15,
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: canSave
                      ? () async {
                          FocusScope.of(context).unfocus();
                          await _handleSaveBill();
                          if (mounted && isSaved) {
                            _customerNameController.clear();
                            _discountController.clear();
                            _mtController.clear();
                            _partialPaymentController.clear();
                          }
                        }
                      : null,
                  style: _buildSaveButtonStyle(),
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.pepsiBlueLight.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        )
                      : const Icon(Icons.save, size: 20),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  ButtonStyle _buildPrintButtonStyle() {
    final hasValidCustomer = _hasValidCustomerForCurrentBill;
    final canEnable = hasValidCustomer && _isPrinterConnected;
    return ElevatedButton.styleFrom(
      backgroundColor: canEnable ? AppColors.pepsiBlue : AppColors.gray300,
      foregroundColor: canEnable ? Colors.white : AppColors.gray500,
      disabledBackgroundColor: AppColors.gray300,
      disabledForegroundColor: AppColors.gray500,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: canEnable ? 2 : 0,
    );
  }

  ButtonStyle _buildSaveButtonStyle() {
    final hasValidCustomer = _hasValidCustomerForCurrentBill;
    final canEnable = hasValidCustomer;
    return ElevatedButton.styleFrom(
      backgroundColor: canEnable ? AppColors.pepsiBlue : AppColors.gray300,
      foregroundColor: canEnable ? Colors.white : AppColors.gray500,
      disabledBackgroundColor: AppColors.gray300,
      disabledForegroundColor: AppColors.gray500,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: canEnable ? 2 : 0,
      padding: EdgeInsets.zero,
    );
  }
}
