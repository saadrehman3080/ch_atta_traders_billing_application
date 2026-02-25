import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/data/models/cleared_bill.dart';
import 'package:flutter/material.dart';

/// Dialog to show the details of a cleared (fully paid) previous-day bill.
/// Shows the original bill info and highlights the amount paid today.
class ClearedBillDetailDialog extends StatefulWidget {
  final ClearedBill clearedBill;

  const ClearedBillDetailDialog({super.key, required this.clearedBill});

  @override
  State<ClearedBillDetailDialog> createState() =>
      _ClearedBillDetailDialogState();
}

class _ClearedBillDetailDialogState extends State<ClearedBillDetailDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrollable = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollable);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkScrollable();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollable);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollable() {
    if (!mounted) return;
    if (_scrollController.hasClients) {
      final isScrollable = _scrollController.position.maxScrollExtent > 0;
      if (isScrollable != _isScrollable) {
        setState(() => _isScrollable = isScrollable);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.clearedBill;
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final totalCrates = BillingCalculations.calculateTotalCrates(bill.products);

    return Dialog(
      backgroundColor: AppColors.pepsiWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
            decoration: const BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: _buildDialogHeader(context),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer and Original Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CUSTOMER',
                                style: AppTextStyles.helperText.copyWith(
                                  color: AppColors.gray500,
                                  letterSpacing: 0.5,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                toTitleCase(bill.customerName),
                                style: AppTextStyles.pageTitleBlack.copyWith(
                                  fontSize: 20,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'BILL DATE',
                              style: AppTextStyles.helperText.copyWith(
                                color: AppColors.gray500,
                                letterSpacing: 0.5,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDateShort(bill.originalDate),
                              style: AppTextStyles.inputText.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Products List
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: bill.products.length,
                            itemBuilder: (context, index) {
                              final product = bill.products[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildProductItem(
                                  '${product.quantity}x',
                                  product.name,
                                  '@${formatCashAmount(product.price)}',
                                  'Rs. ${formatCashAmount(product.price * product.quantity)}',
                                ),
                              );
                            },
                          ),
                          if (_isScrollable)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: AppColors.pepsiBlue.withValues(
                                        alpha: 0.9,
                                      ),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Divider
                    const Divider(color: AppColors.gray300, thickness: 1),
                    const SizedBox(height: 12),

                    // Total Items
                    _buildInfoRow('Total Items', '$totalItems'),
                    if (totalCrates > 0) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Total Crates', '$totalCrates'),
                    ],
                    const SizedBox(height: 8),

                    // Grand Total
                    _buildInfoRow(
                      bill.discount > 0 ? 'Subtotal' : 'Grand Total',
                      'Rs. ${formatCashAmount(bill.originalTotal)}',
                      isBold: bill.discount == 0,
                    ),

                    // Discount
                    if (bill.discount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount',
                            style: AppTextStyles.inputText.copyWith(
                              color: AppColors.gray500,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '- Rs. ${formatCashAmount(bill.discount)}',
                            style: AppTextStyles.productItemTotal.copyWith(
                              fontSize: 14,
                              color: AppColors.pepsiRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildInfoRow(
                        'Net Amount',
                        'Rs. ${formatCashAmount(bill.netTotal)}',
                        isBold: true,
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(color: AppColors.gray300, thickness: 1),
                    const SizedBox(height: 12),

                    // ===== Today's Payment Section =====
                    _buildTodayPaymentSection(bill),

                    // Partial Payment History
                    if (bill.partialPayments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildPaymentHistorySection(bill),
                    ],

                    const SizedBox(height: 20),

                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pepsiBlue,
                          foregroundColor: AppColors.pepsiWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Close',
                          style: AppTextStyles.smallButton.copyWith(
                            color: AppColors.pepsiWhite,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    final isPartial = widget.clearedBill.isPartialPayment;
    final statusColor = isPartial ? Colors.orange : Colors.green;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bill Details',
                style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPartial
                              ? Icons.timelapse_outlined
                              : Icons.check_circle,
                          color: statusColor.shade700,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPartial ? 'Partial Payment' : 'Fully Cleared',
                          style: AppTextStyles.helperText.copyWith(
                            color: statusColor.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      truncateBillId(widget.clearedBill.billId),
                      style: AppTextStyles.helperText.copyWith(
                        color: AppColors.gray500,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.pepsiWhite,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.pepsiBlue, width: 1.5),
          ),
          child: IconButton(
            onPressed: () {
              if (mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close, color: AppColors.pepsiBlue, size: 24),
            padding: const EdgeInsets.all(0),
            constraints: const BoxConstraints(),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
        ),
      ],
    );
  }

  /// Builds the "Today's Payment" section highlighting what was paid to clear the bill
  Widget _buildTodayPaymentSection(ClearedBill bill) {
    final isPartial = bill.isPartialPayment;
    final sectionColor = isPartial ? Colors.orange : Colors.green;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sectionColor.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sectionColor.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPartial ? Icons.timelapse_outlined : Icons.check_circle,
                color: sectionColor.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPartial ? 'Payment Received Today' : 'Cleared Today',
                  style: AppTextStyles.productItemName.copyWith(
                    color: sectionColor.shade800,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.clearedBill.formattedClearedTime,
                style: AppTextStyles.helperText.copyWith(
                  color: sectionColor.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cash paid today
          if (bill.amountPaidToday > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: sectionColor.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cash Received',
                      style: AppTextStyles.helperText.copyWith(
                        color: sectionColor.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Rs. ${formatCashAmount(bill.amountPaidToday)}',
                  style: AppTextStyles.productItemTotal.copyWith(
                    color: sectionColor.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          // Crates returned today
          if (bill.cratesReturnedToday > 0) ...[
            if (bill.amountPaidToday > 0) const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.recycling_outlined,
                      color: Colors.orange.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Crates Returned',
                      style: AppTextStyles.helperText.copyWith(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${bill.cratesReturnedToday}',
                  style: AppTextStyles.productItemTotal.copyWith(
                    color: Colors.orange.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          // Remaining amount for partial payments
          if (isPartial &&
              (bill.remainingAmountAfterPayment > 0 ||
                  bill.remainingCratesAfterPayment > 0)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.pending_outlined,
                        color: Colors.red.shade400,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Still Remaining',
                        style: AppTextStyles.helperText.copyWith(
                          color: Colors.red.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (bill.remainingAmountAfterPayment > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cash Due',
                          style: AppTextStyles.helperText.copyWith(
                            color: Colors.red.shade400,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Rs. ${formatCashAmount(bill.remainingAmountAfterPayment)}',
                          style: AppTextStyles.productItemTotal.copyWith(
                            color: Colors.red.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  if (bill.remainingCratesAfterPayment > 0) ...[
                    if (bill.remainingAmountAfterPayment > 0)
                      const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Crates Due',
                          style: AppTextStyles.helperText.copyWith(
                            color: Colors.red.shade400,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${bill.remainingCratesAfterPayment}',
                          style: AppTextStyles.productItemTotal.copyWith(
                            color: Colors.red.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // If cash was already paid (cash+MT bill), show info
          if (bill.wasCashAlreadyPaid &&
              bill.amountPaidToday == 0 &&
              bill.cratesReturnedToday > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.pepsiBlue,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cash was already paid. Only crates were returned today.',
                      style: AppTextStyles.helperText.copyWith(
                        color: AppColors.pepsiBlue,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the partial payment history section
  Widget _buildPaymentHistorySection(ClearedBill bill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAYMENT HISTORY',
          style: AppTextStyles.helperText.copyWith(
            color: AppColors.gray500,
            letterSpacing: 0.5,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              // Total Bill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Bill',
                    style: AppTextStyles.helperText.copyWith(
                      fontSize: 13,
                      color: AppColors.gray500,
                    ),
                  ),
                  Text(
                    'Rs. ${formatCashAmount(bill.netTotal)}',
                    style: AppTextStyles.productItemTotal.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Each partial payment
              ...bill.partialPayments.map((payment) {
                final dateStr =
                    '${payment.date.day}-${payment.date.month}-${payment.date.year}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Paid on $dateStr',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '- Rs. ${formatCashAmount(payment.amount)}',
                        style: AppTextStyles.productItemTotal.copyWith(
                          fontSize: 13,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              // Final payment / today's payment
              if (bill.amountPaidToday > 0 && !bill.isPartialPayment) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Final Payment (Today)',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '- Rs. ${formatCashAmount(bill.amountPaidToday)}',
                        style: AppTextStyles.productItemTotal.copyWith(
                          fontSize: 13,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Today's partial payment entry (for partial payment bills)
              if (bill.amountPaidToday > 0 && bill.isPartialPayment) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timelapse_outlined,
                            size: 14,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Received Today',
                            style: AppTextStyles.helperText.copyWith(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '- Rs. ${formatCashAmount(bill.amountPaidToday)}',
                        style: AppTextStyles.productItemTotal.copyWith(
                          fontSize: 13,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(color: AppColors.gray300, thickness: 1),
              const SizedBox(height: 4),
              // Bottom status: Fully Paid or Remaining Due
              if (!bill.isPartialPayment)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fully Paid',
                      style: AppTextStyles.productItemTotal.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'Rs. 0 Due',
                      style: AppTextStyles.productItemTotal.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining Due',
                      style: AppTextStyles.productItemTotal.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.red[600],
                      ),
                    ),
                    Text(
                      'Rs. ${formatCashAmount(bill.remainingAmountAfterPayment)}',
                      style: AppTextStyles.productItemTotal.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.red[600],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.inputText.copyWith(
            color: isBold ? Colors.black87 : AppColors.gray500,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.productItemTotal.copyWith(
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProductItem(
    String quantity,
    String name,
    String price,
    String total,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.pepsiBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              quantity,
              style: AppTextStyles.productItemQuantity.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.pepsiBlue,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.productItemName.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  price,
                  style: AppTextStyles.helperText.copyWith(
                    color: AppColors.gray500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            total,
            style: AppTextStyles.productItemTotal.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
