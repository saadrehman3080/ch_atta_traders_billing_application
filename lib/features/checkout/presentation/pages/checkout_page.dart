import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/features/credit/providers/credit_provider.dart';
import 'package:ch_atta_traders_billing_application/features/sales/providers/sale_provider.dart';
import 'package:flutter/material.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart';

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

    if (value < 0) {
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
    try {
      // Check if printer is connected
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'No printer connected. Please connect a printer first.',
            type: SnackBarType.error,
          );
        }
        return;
      }

      List<int> bytes = [];

      // Store name - centered, large text
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
      bytes.addAll('CH. ATTA TRADERS\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('\n'.codeUnits);

      // Separator
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Date and Bill ID - left align
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');
      bytes.addAll('Date: ${dateFormatter.format(date)}\n'.codeUnits);
      bytes.addAll('Bill ID: ${truncateBillId(billId)}\n'.codeUnits);
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Customer name - bold
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Customer: ${toTitleCase(customerName)}\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off

      // Salesman name
      bytes.addAll('Salesman: ${toTitleCase(salesmanName)}\n'.codeUnits);

      // Payment type indicator - bold if credit
      if (paymentType == 'credit') {
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('Payment: CREDIT\n'.codeUnits);
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      } else {
        bytes.addAll('Payment: Cash\n'.codeUnits);
      }
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Items header - bold
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Item                       Total\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('--------------------------------\n'.codeUnits);

      // Add each product
      for (final product in products) {
        final itemTotal = product.price * product.quantity;

        // Product name (truncate if too long)
        String productName = product.name;
        if (productName.length > 20) {
          productName = '${productName.substring(0, 17)}...';
        }
        bytes.addAll('$productName\n'.codeUnits);

        // Quantity and price details
        final qtyPrice =
            '  ${product.quantity}x @ Rs.${formatCashAmount(product.price)}';
        final totalStr = 'Rs.${formatCashAmount(itemTotal)}';
        final spacing = 32 - qtyPrice.length - totalStr.length;
        final line = qtyPrice + (' ' * (spacing > 0 ? spacing : 1)) + totalStr;
        bytes.addAll('$line\n'.codeUnits);
      }

      bytes.addAll('--------------------------------\n'.codeUnits);

      // Calculate totals
      final totalItems = BillingCalculations.calculateTotalItems(products);
      final grandTotal = BillingCalculations.calculateGrandTotal(products);

      // Total items
      bytes.addAll('Total Items: $totalItems\n'.codeUnits);

      // MT details if user entered any value (including 0)
      if (mtCollected != null && mtRemaining != null) {
        bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
        bytes.addAll('MT Collected: $mtCollected\n'.codeUnits);
        bytes.addAll('MT Remaining: $mtRemaining\n'.codeUnits);
        bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      }

      // Subtotal if discount exists
      if (discount > 0) {
        bytes.addAll(
          'Subtotal: Rs.${formatCashAmount(grandTotal)}\n'.codeUnits,
        );
        bytes.addAll(
          'Discount: - Rs.${formatCashAmount(discount)}\n'.codeUnits,
        );
        bytes.addAll('--------------------------------\n'.codeUnits);
      }

      // Grand total - large and bold
      final netAmount = grandTotal - discount;
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('\x1D\x21\x11'.codeUnits); // Double size
      bytes.addAll('TOTAL: Rs.${formatCashAmount(netAmount)}\n'.codeUnits);
      bytes.addAll('\x1D\x21\x00'.codeUnits); // Normal size
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('\n'.codeUnits);

      // Footer - center align, bold
      bytes.addAll('\x1B\x61\x01'.codeUnits); // Center align
      bytes.addAll('\x1B\x45\x01'.codeUnits); // Bold on
      bytes.addAll('Thank you for your business!\n'.codeUnits);
      bytes.addAll('\x1B\x45\x00'.codeUnits); // Bold off
      bytes.addAll('\x1B\x61\x00'.codeUnits); // Left align
      bytes.addAll('\n\n\n'.codeUnits);

      // Send to printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);

      if (mounted) {
        if (result) {
          CustomSnackBar.show(
            context,
            message: 'Bill printed successfully',
            type: SnackBarType.success,
          );
        } else {
          CustomSnackBar.show(
            context,
            message: 'Failed to print bill',
            type: SnackBarType.error,
          );
        }
      }
    } catch (e) {
      debugPrint('Error printing bill: $e');
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Error printing bill: ${e.toString()}',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _handleSaveBill() async {
    setState(() {
      _isSaving = true;
    });

    // Generate bill ID using UUID
    final billId = _uuid.v4();

    // Get salesman identifier (for Firebase path) from SharedPreferences
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: 'Salesman info not found. Please login again.',
          type: SnackBarType.error,
        );
      }
      setState(() {
        _isSaving = false;
      });
      return;
    }

    // Determine if MT is collected
    final bool hasMt = _mtController.text.trim().isNotEmpty;

    // Save to Daily Sales only if: payment is cash AND MT is empty
    if (_paymentType == 'cash' && !hasMt) {
      // Create SaleHistory object
      final sale = SaleHistory(
        billId: billId,
        customerName: _customerNameController.text.trim(),
        date: DateTime.now(),
        products: _selectedProducts
            .map(
              (p) =>
                  Product(name: p.name, price: p.price, quantity: p.quantity),
            )
            .toList(),
        discount: _discount,
      );

      // Save to Firebase
      final success = await _saleProvider.saveSale(sale, salesmanIdentifier);

      setState(() {
        _isSaving = false;
      });

      if (success) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Bill saved successfully',
            type: SnackBarType.success,
          );
        }

        // Call the original onPrint callback
        widget.onPrint();
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: _saleProvider.errorMessage ?? 'Failed to save bill',
            type: SnackBarType.error,
          );
        }
      }
    } else {
      // Save to Credit History
      final totalRbQuantity = _getTotalRbQuantity();
      final cratesDue = hasMt ? (totalRbQuantity - _mt) : 0;

      final credit = CreditHistory(
        billId: billId,
        customerName: _customerNameController.text.trim(),
        date: DateTime.now(),
        products: _selectedProducts
            .map(
              (p) =>
                  Product(name: p.name, price: p.price, quantity: p.quantity),
            )
            .toList(),
        discount: _discount,
        isPaid: _paymentType == 'cash',
        amountDue: _grandTotal,
        cratesDue: cratesDue,
      );

      // Save to Firebase
      final success = await _creditProvider.saveCredit(
        credit,
        salesmanIdentifier,
      );

      setState(() {
        _isSaving = false;
      });

      if (success) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Credit saved successfully',
            type: SnackBarType.success,
          );
        }

        // Call the original onPrint callback
        widget.onPrint();
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: _creditProvider.errorMessage ?? 'Failed to save credit',
            type: SnackBarType.error,
          );
        }
      }
    }
  }

  Future<void> _handlePrintBill() async {
    setState(() {
      _isPrinting = true;
    });

    // Generate bill ID using UUID
    final billId = _uuid.v4();

    // Get salesman name (for printing) and identifier (for Firebase path)
    final salesmanName = await AppPreferences.instance.salesmanName;
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
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
      setState(() {
        _isPrinting = false;
      });
      return;
    }

    // Determine if MT is collected
    final bool hasMt = _mtController.text.trim().isNotEmpty;

    // Save to Daily Sales only if: payment is cash AND MT is empty
    if (_paymentType == 'cash' && !hasMt) {
      // Create SaleHistory object
      final sale = SaleHistory(
        billId: billId,
        customerName: _customerNameController.text.trim(),
        date: DateTime.now(),
        products: _selectedProducts
            .map(
              (p) =>
                  Product(name: p.name, price: p.price, quantity: p.quantity),
            )
            .toList(),
        discount: _discount,
      );

      // Save to Firebase
      final success = await _saleProvider.saveSale(sale, salesmanIdentifier);

      if (success) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Bill saved successfully',
            type: SnackBarType.success,
          );
        }

        // Print the bill
        await _printBill(
          billId: billId,
          customerName: _customerNameController.text.trim(),
          date: DateTime.now(),
          products: _selectedProducts,
          discount: _discount,
          salesmanName: salesmanName,
          paymentType: _paymentType,
        );

        setState(() {
          _isPrinting = false;
        });

        // Call the original onPrint callback
        widget.onPrint();
      } else {
        setState(() {
          _isPrinting = false;
        });

        if (mounted) {
          CustomSnackBar.show(
            context,
            message: _saleProvider.errorMessage ?? 'Failed to save bill',
            type: SnackBarType.error,
          );
        }
      }
    } else {
      // Save to Credit History if:
      // 1. Payment is credit AND MT is not empty
      // 2. Payment is cash AND MT is not empty
      // 3. Payment is credit AND MT is empty

      // Calculate cratesDue: 0 if MT not collected, otherwise Remaining MT - Collected MT
      final totalRbQuantity = _getTotalRbQuantity();
      final cratesDue = hasMt ? (totalRbQuantity - _mt) : 0;

      final credit = CreditHistory(
        billId: billId,
        customerName: _customerNameController.text.trim(),
        date: DateTime.now(),
        products: _selectedProducts
            .map(
              (p) =>
                  Product(name: p.name, price: p.price, quantity: p.quantity),
            )
            .toList(),
        discount: _discount,
        isPaid: _paymentType == 'cash', // true if cash, false if credit
        amountDue:
            _grandTotal, // grandTotal already includes discount calculation
        cratesDue: cratesDue, // Remaining MT - Collected MT
      );

      // Save to Firebase
      final success = await _creditProvider.saveCredit(
        credit,
        salesmanIdentifier,
      );

      if (success) {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: 'Credit saved successfully',
            type: SnackBarType.success,
          );
        }

        // Print the bill
        await _printBill(
          billId: billId,
          customerName: _customerNameController.text.trim(),
          date: DateTime.now(),
          products: _selectedProducts,
          discount: _discount,
          salesmanName: salesmanName,
          paymentType: _paymentType,
          mtCollected: hasMt ? _mt : null,
          mtRemaining: hasMt ? cratesDue : null,
        );

        setState(() {
          _isPrinting = false;
        });

        // Call the original onPrint callback
        widget.onPrint();
      } else {
        setState(() {
          _isPrinting = false;
        });

        if (mounted) {
          CustomSnackBar.show(
            context,
            message: _creditProvider.errorMessage ?? 'Failed to save credit',
            type: SnackBarType.error,
          );
        }
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
    return Theme(
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
    );
  }

  InputDecoration _buildCustomerFieldDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: "Customer Name *",
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

        return Row(
          children: [
            Expanded(
              flex: 85,
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed:
                      (_hasCustomerName &&
                          !isLoading &&
                          !_isSaving &&
                          !_isPrinting)
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
                      : const Icon(Icons.print, size: 20),
                  label: Text(
                    _isPrinting ? 'Saving & Printing...' : "Print Bill",
                    style: AppTextStyles.smallButton.copyWith(
                      color:
                          (_hasCustomerName &&
                              !isLoading &&
                              !_isSaving &&
                              !_isPrinting)
                          ? Colors.white
                          : AppColors.gray500,
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
                  onPressed:
                      (_hasCustomerName &&
                          !isLoading &&
                          !_isSaving &&
                          !_isPrinting)
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
    return ElevatedButton.styleFrom(
      backgroundColor: _hasCustomerName
          ? AppColors.pepsiBlue
          : AppColors.gray300,
      foregroundColor: _hasCustomerName ? Colors.white : AppColors.gray500,
      disabledBackgroundColor: AppColors.gray300,
      disabledForegroundColor: AppColors.gray500,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: _hasCustomerName ? 2 : 0,
    );
  }

  ButtonStyle _buildSaveButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _hasCustomerName
          ? AppColors.pepsiBlue
          : AppColors.gray300,
      foregroundColor: _hasCustomerName ? Colors.white : AppColors.gray500,
      disabledBackgroundColor: AppColors.gray300,
      disabledForegroundColor: AppColors.gray500,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: _hasCustomerName ? 2 : 0,
      padding: EdgeInsets.zero,
    );
  }
}
