import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/features/credit/providers/credit_provider.dart';
import 'package:ch_atta_traders_billing_application/features/sales/providers/sale_provider.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_connection_service.dart';
import 'package:flutter/material.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/services/printer/bill_printer.dart';

class CheckoutPage extends StatefulWidget {
  final List<Product> products;
  final VoidCallback onPrint;
  final VoidCallback onDismiss;

  const CheckoutPage({
    super.key,
    required this.products,
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
  bool _hasCustomerName = false;
  bool _isPrinterConnected = true; // Default to true, will be updated on check
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _mtController = TextEditingController();
  bool _isScrollable = false;
  String _paymentType = 'cash';
  int _discount = 0;
  int _mt = 0;
  bool _isSaving = false;
  bool _isPrinting = false;
  bool _isAnonymousCustomer = false; // When true, skip customer name on bill

  @override
  void initState() {
    super.initState();
    _saleProvider = SaleProvider();
    _creditProvider = CreditProvider();
    _customerNameController.addListener(_updateButtonState);
    _discountController.addListener(_updateDiscount);
    _mtController.addListener(_updateMt);
    _scrollController.addListener(_checkScrollable);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollable());
    _checkPrinterConnection();
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

  @override
  void dispose() {
    _customerNameController.removeListener(_updateButtonState);
    _discountController.removeListener(_updateDiscount);
    _mtController.removeListener(_updateMt);
    _scrollController.removeListener(_checkScrollable);
    _scrollController.dispose();
    _customerNameController.dispose();
    _discountController.dispose();
    _mtController.dispose();
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
    setState(() {
      _hasCustomerName = _customerNameController.text.trim().isNotEmpty;
    });
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
    return _isAnonymousCustomer || enteredName.isEmpty
        ? 'Walk-In Customer'
        : enteredName;
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
  dynamic _prepareBillData(String billId) {
    final customerName = _getCustomerName();
    final products = _selectedProducts
        .map((p) => Product(name: p.name, price: p.price, quantity: p.quantity))
        .toList();

    if (_shouldSaveToDailySales()) {
      // Fully completed cash sale - no tracking needed
      return SaleHistory(
        billId: billId,
        customerName: customerName,
        date: DateTime.now(),
        products: products,
        discount: _discount,
        billType: BillType.cash,
      );
    } else {
      // Needs tracking (credit payment or MT pending)
      final hasMt = _mtController.text.trim().isNotEmpty;
      final totalRbQuantity = _getTotalRbQuantity();
      final cratesDue = hasMt ? (totalRbQuantity - _mt) : 0;

      return CreditHistory(
        billId: billId,
        customerName: customerName,
        date: DateTime.now(),
        products: products,
        discount: _discount,
        isPaid:
            _paymentType ==
            'cash', // True if cash (only MT pending), false if credit
        amountDue: _grandTotal,
        cratesDue: cratesDue,
        billType: BillType.credit,
      );
    }
  }

  /// Validates checkout inputs before saving/printing
  /// Returns error message if invalid, null if valid
  String? _validateCheckout() {
    // Validate customer name (must be entered or anonymous for all bills)
    if (!_hasCustomerName && !_isAnonymousCustomer) {
      return 'Please enter customer name or select anonymous';
    }

    // For credit payments, customer name is required (can't be anonymous)
    if (_paymentType == 'credit' && _isAnonymousCustomer) {
      return 'Customer name required for credit bills';
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

  /// Saves bill to appropriate collection (Daily Sales or Credit History)
  Future<bool> _saveBillToFirebase(
    String billId,
    String salesmanIdentifier,
  ) async {
    final billData = _prepareBillData(billId);

    if (billData is SaleHistory) {
      return await _saleProvider.saveSale(billData, salesmanIdentifier);
    } else if (billData is CreditHistory) {
      return await _creditProvider.saveCredit(billData, salesmanIdentifier);
    }
    return false;
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
    );

    if (mounted) {
      if (result.success) {
        CustomSnackBar.show(
          context,
          message: 'Bill printed successfully',
          type: SnackBarType.success,
        );
      } else {
        CustomSnackBar.show(
          context,
          message: result.errorMessage ?? 'Failed to print bill',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _handleSaveBill() async {
    // Validate inputs
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
      // Get salesman identifier from SharedPreferences
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

      // Generate bill ID and save to Firebase
      final billId = _uuid.v4();
      final success = await _saveBillToFirebase(billId, salesmanIdentifier);

      if (mounted) {
        if (success) {
          final billType = _shouldSaveToDailySales() ? 'Bill' : 'Credit';
          CustomSnackBar.show(
            context,
            message: '$billType saved successfully',
            type: SnackBarType.success,
          );
          widget.onPrint();
        } else {
          final errorMsg = _shouldSaveToDailySales()
              ? (_saleProvider.errorMessage ?? 'Failed to save bill')
              : (_creditProvider.errorMessage ?? 'Failed to save credit');
          CustomSnackBar.show(
            context,
            message: errorMsg,
            type: SnackBarType.error,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handlePrintBill() async {
    // Validate inputs
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

    // Check printer connection
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
      // Get salesman info from SharedPreferences
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

      // Generate bill ID and save to Firebase
      final billId = _uuid.v4();
      final success = await _saveBillToFirebase(billId, salesmanIdentifier);

      if (!success) {
        if (mounted) {
          final errorMsg = _shouldSaveToDailySales()
              ? (_saleProvider.errorMessage ?? 'Failed to save bill')
              : (_creditProvider.errorMessage ?? 'Failed to save credit');
          CustomSnackBar.show(
            context,
            message: errorMsg,
            type: SnackBarType.error,
          );
        }
        return;
      }

      // Show success message
      if (mounted) {
        final billType = _shouldSaveToDailySales() ? 'Bill' : 'Credit';
        CustomSnackBar.show(
          context,
          message: '$billType saved successfully',
          type: SnackBarType.success,
        );
      }

      // Print the bill
      final hasMt = _mtController.text.trim().isNotEmpty;
      final totalRbQuantity = _getTotalRbQuantity();
      final cratesDue = hasMt ? (totalRbQuantity - _mt) : 0;

      await _printBill(
        billId: billId,
        customerName: _getCustomerName(),
        date: DateTime.now(),
        products: _selectedProducts,
        discount: _discount,
        salesmanName: salesmanName,
        paymentType: _paymentType,
        mtCollected: hasMt ? _mt : null,
        mtRemaining: hasMt ? cratesDue : null,
      );

      // Call the original onPrint callback
      if (mounted) {
        widget.onPrint();
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  // ========== Main Container Building Methods ==========

  BoxDecoration _buildContainerDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 3,
        margin: const EdgeInsets.only(bottom: 12),
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
      color: AppColors.pepsiBlueLight.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: AppColors.pepsiBlueLight.withValues(alpha: 0.2),
        width: 1,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.pepsiBlue,
        borderRadius: BorderRadius.circular(6),
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
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300, width: 1),
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
    return Padding(
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
        _buildAnonymousToggle(),
      ],
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
                setState(() {
                  _isAnonymousCustomer = !_isAnonymousCustomer;
                  // Clear focus and text when toggling anonymous customer ON
                  if (_isAnonymousCustomer) {
                    FocusScope.of(context).unfocus();
                    _customerNameController.clear();
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
                : (_isAnonymousCustomer ? AppColors.pepsiBlue : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDisabled
                  ? AppColors.gray300
                  : (_isAnonymousCustomer
                        ? AppColors.pepsiBlue
                        : AppColors.gray300),
              width: 1,
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
      fillColor: Colors.white,
      hintText: "Customer Name",
      hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
      prefixIcon: const Icon(Icons.person_outline, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gray300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
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
      fillColor: Colors.white,
      hintText: "Discount (Optional)",
      hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
      prefixIcon: const Icon(Icons.discount_outlined, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gray300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.pepsiBlue, width: 1.5),
      ),
    );
  }

  Widget _buildMtField() {
    return Theme(
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
          color: Colors.black87,
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
    );
  }

  InputDecoration _buildMtFieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: "Collected MT (Optional)",
      hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
      prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.gray300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.pepsiBlue, width: 1.5),
      ),
    );
  }

  Widget _buildPrintButton() {
    return Consumer2<SaleProvider, CreditProvider>(
      builder: (context, saleProvider, creditProvider, child) {
        final isLoading = saleProvider.isSaving || creditProvider.isSaving;
        final isSaved =
            saleProvider.state == SaleState.saved ||
            creditProvider.state == CreditState.saved;
        final hasValidCustomer = _hasCustomerName || _isAnonymousCustomer;
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
    final hasValidCustomer = _hasCustomerName || _isAnonymousCustomer;
    final canEnable = hasValidCustomer && _isPrinterConnected;
    return ElevatedButton.styleFrom(
      backgroundColor: canEnable ? AppColors.pepsiBlue : AppColors.gray300,
      foregroundColor: canEnable ? Colors.white : AppColors.gray500,
      disabledBackgroundColor: AppColors.gray300,
      disabledForegroundColor: AppColors.gray500,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: canEnable ? 2 : 0,
    );
  }

  ButtonStyle _buildSaveButtonStyle() {
    final hasValidCustomer = _hasCustomerName || _isAnonymousCustomer;
    final canEnable = hasValidCustomer;
    return ElevatedButton.styleFrom(
      backgroundColor: canEnable ? AppColors.pepsiBlue : AppColors.gray300,
      foregroundColor: canEnable ? Colors.white : AppColors.gray500,
      disabledBackgroundColor: AppColors.gray300,
      disabledForegroundColor: AppColors.gray500,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: canEnable ? 2 : 0,
      padding: EdgeInsets.zero,
    );
  }
}
