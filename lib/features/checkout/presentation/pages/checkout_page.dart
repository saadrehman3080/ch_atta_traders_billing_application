import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/data/models/product.dart';
import 'package:flutter/material.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/constants/formated_number.dart';

class CheckoutPage extends StatefulWidget {
  final TextEditingController customerController;
  final List<Product> products;
  final VoidCallback onPrint;
  final VoidCallback onDismiss;

  const CheckoutPage({
    super.key,
    required this.customerController,
    required this.products,
    required this.onPrint,
    required this.onDismiss,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _hasCustomerName = false;
  final ScrollController _scrollController = ScrollController();
  bool _isScrollable = false;
  String _paymentType = 'cash';

  @override
  void initState() {
    super.initState();
    widget.customerController.addListener(_updateButtonState);
    _scrollController.addListener(_checkScrollable);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollable());
  }

  @override
  void dispose() {
    widget.customerController.removeListener(_updateButtonState);
    _scrollController.removeListener(_checkScrollable);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      _hasCustomerName = widget.customerController.text.trim().isNotEmpty;
    });
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

  int get _selectedItemsCount {
    return BillingCalculations.countSelectedProducts(widget.products);
  }

  List<Product> get _selectedProducts {
    return BillingCalculations.getSelectedProducts(widget.products);
  }

  int get _grandTotal {
    return BillingCalculations.calculateGrandTotal(widget.products);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.gray400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildSummaryInfo(),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProductsList(context),
                  const SizedBox(height: 12),
                  _buildPaymentTypeSelector(),
                  const SizedBox(height: 12),
                  _buildCustomerNameField(),
                  const SizedBox(height: 12),
                  _buildPrintButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$_selectedItemsCount items selected",
          style: AppTextStyles.billingItems.copyWith(color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          "Rs. ${formatNumber(_grandTotal)}",
          style: AppTextStyles.billingTotal.copyWith(color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildProductsList(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 250),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray300, width: 1),
        ),
        child: Stack(
          children: [
            ListView.separated(
              controller: _scrollController,
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: _selectedProducts.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.gray300, height: 16),
              itemBuilder: (context, index) {
                return _buildProductListItem(_selectedProducts[index]);
              },
            ),
            if (_isScrollable) _buildScrollIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListItem(Product product) {
    final itemTotal = product.price * product.quantity;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(product.name, style: AppTextStyles.productItemName),
        ),
        const SizedBox(width: 8),
        Text('x${product.quantity}', style: AppTextStyles.productItemQuantity),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            'Rs. ${formatNumber(itemTotal)}',
            textAlign: TextAlign.right,
            style: AppTextStyles.productItemTotal,
          ),
        ),
      ],
    );
  }

  Widget _buildScrollIndicator() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Container(
          height: 40,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.iconIndicatorColor,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTypeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment<String>(
            value: 'cash',
            label: Text('Cash'),
            icon: Icon(Icons.payments),
          ),
          ButtonSegment<String>(
            value: 'loan',
            label: Text('Loan'),
            icon: Icon(Icons.account_balance),
          ),
        ],
        selected: {_paymentType},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            _paymentType = newSelection.first;
          });
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.pepsiBlue;
            }
            return AppColors.gray100;
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
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerNameField() {
    return TextField(
      controller: widget.customerController,
      style: AppTextStyles.inputText.copyWith(color: Colors.black87),
      cursorColor: AppColors.pepsiBlue,
      textInputAction: TextInputAction.done,
      onSubmitted: (value) {
        FocusScope.of(context).unfocus();
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.gray50,
        hintText: "Customer Name (Required)",
        hintStyle: AppTextStyles.inputHint,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gray300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.pepsiBlue, width: 2),
        ),
      ),
    );
  }

  Widget _buildPrintButton() {
    return GestureDetector(
      onTap: _hasCustomerName ? widget.onPrint : null,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: _hasCustomerName ? AppColors.pepsiBlue : AppColors.gray300,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasCustomerName ? Colors.transparent : AppColors.gray400,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.print,
              color: _hasCustomerName ? Colors.white : AppColors.gray500,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              "Print Bill",
              style: AppTextStyles.smallButton.copyWith(
                color: _hasCustomerName ? Colors.white : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
