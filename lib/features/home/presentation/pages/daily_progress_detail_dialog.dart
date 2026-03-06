import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/data/models/daily_progress.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Full-screen dialog showing the complete breakdown of a daily sales record.
/// Inspired by the admin app's sales_summary_dialog.
class DailyProgressDetailDialog extends StatelessWidget {
  final DailyProgress record;

  const DailyProgressDetailDialog({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            _buildProductsSection(),
            _buildExpensesSection(),
            _buildEmptyCratesSection(),
            _buildCashReceivedSection(),
            _buildFinalResultSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.black87),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Daily Breakdown',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.gray300, height: 1),
      ),
    );
  }

  // ========== Header Card ==========

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.pepsiBlue, AppColors.pepsiBlueLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.pepsiBlue.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.salesmanName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(record.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: Colors.white.withValues(alpha: 0.7),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDateLabel(record.date),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          if (record.completedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent.withValues(alpha: 0.8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Completed at ${DateFormat('hh:mm a').format(record.completedAt!)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Summary row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderStat(
                'Total Sales',
                _formatCurrency(record.totalSalesAmount),
              ),
              _buildHeaderStat('Cash', _formatCurrency(record.cashReceived)),
              _buildHeaderStat('Items', '${record.totalItemsSold}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isCompleted = status == 'completed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.greenAccent.withValues(alpha: 0.2)
            : Colors.orangeAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? 'Completed' : 'In Progress',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isCompleted ? Colors.greenAccent : Colors.orangeAccent,
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ========== Products Section ==========

  Widget _buildProductsSection() {
    if (record.products.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      title: 'Products',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Product', style: _tableHeaderStyle),
                ),
                Expanded(
                  child: Text(
                    'Out',
                    style: _tableHeaderStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Ret',
                    style: _tableHeaderStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Sold',
                    style: _tableHeaderStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Amount',
                    style: _tableHeaderStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Product rows
          ...record.products.map((product) => _buildProductRow(product)),

          const SizedBox(height: 8),
          // Total row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pepsiBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${record.totalItemsTakenOut}',
                    style: _tableTotalStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${record.totalItemsReturned}',
                    style: _tableTotalStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${record.totalItemsSold}',
                    style: _tableTotalStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatCurrency(record.totalSalesAmount),
                    style: _tableTotalStyle,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(DailyProgressProduct product) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.gray300.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              product.name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${product.takenOut}',
              style: _tableCellStyle,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${product.returned}',
              style: _tableCellStyle.copyWith(
                color: product.returned > 0
                    ? Colors.orange.shade700
                    : AppColors.gray500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '${product.sold}',
              style: _tableCellStyle.copyWith(
                color: AppColors.pepsiBlue,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatCurrency(product.totalAmount),
              style: _tableCellStyle.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Cash Received Section ==========

  Widget _buildCashReceivedSection() {
    return _buildSection(
      title: 'Cash Received',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _buildDetailRow(
            'Total Sales Amount',
            _formatCurrency(record.totalSalesAmount),
          ),
          _buildDetailRow(
            'Total Expenses',
            '- ${_formatCurrency(record.totalExpenses)}',
            valueColor: AppColors.pepsiRed,
          ),
          _buildDetailRow(
            'Cash Received',
            _formatCurrency(record.cashReceived),
            valueColor: AppColors.textSuccess,
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ========== Expenses Section ==========

  Widget _buildExpensesSection() {
    final expenses = record.expenses;
    return _buildSection(
      title: 'Expenses',
      icon: Icons.money_off_outlined,
      child: Column(
        children: [
          _buildDetailRow('Discount', _formatCurrency(expenses.discount)),
          _buildDetailRow('Petrol', _formatCurrency(expenses.petrol)),
          _buildDetailRow('Food', _formatCurrency(expenses.food)),
          if (expenses.other > 0)
            _buildDetailRow(
              expenses.otherDescription.isNotEmpty
                  ? 'Other (${expenses.otherDescription})'
                  : 'Other',
              _formatCurrency(expenses.other),
            ),
          const SizedBox(height: 4),
          Container(height: 1, color: AppColors.gray300.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          _buildDetailRow(
            'Total Expenses',
            _formatCurrency(expenses.total),
            valueColor: AppColors.pepsiRed,
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ========== Empty Crates Section ==========

  Widget _buildEmptyCratesSection() {
    final crates = record.emptyCrates;
    return _buildSection(
      title: 'Empty Crates (MT)',
      icon: Icons.wine_bar_outlined,
      child: Column(
        children: [
          _buildDetailRow('Issued', '${crates.issued}'),
          _buildDetailRow(
            'RB Products Returned',
            '${crates.rbProductsReturned}',
          ),
          _buildDetailRow('Returned', '${crates.returned}'),
          const SizedBox(height: 4),
          Container(height: 1, color: AppColors.gray300.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          if (crates.short > 0)
            _buildDetailRow(
              'Short',
              '${crates.short}',
              valueColor: Colors.orange.shade700,
              isBold: true,
            ),
          if (crates.excess > 0)
            _buildDetailRow(
              'Excess',
              '${crates.excess}',
              valueColor: AppColors.textSuccess,
              isBold: true,
            ),
          if (crates.short == 0 && crates.excess == 0)
            _buildDetailRow(
              'Status',
              'Balanced',
              valueColor: AppColors.textSuccess,
              isBold: true,
            ),
        ],
      ),
    );
  }

  // ========== Final Result Section ==========

  Widget _buildFinalResultSection() {
    final isShort = record.finalAmount > 0;
    final isExcess = record.finalAmount < 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isShort
            ? AppColors.pepsiRed.withValues(alpha: 0.06)
            : isExcess
            ? AppColors.textSuccess.withValues(alpha: 0.08)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isShort
              ? AppColors.pepsiRed.withValues(alpha: 0.2)
              : isExcess
              ? AppColors.textSuccess.withValues(alpha: 0.3)
              : AppColors.gray300.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isShort
                  ? AppColors.pepsiRed.withValues(alpha: 0.12)
                  : isExcess
                  ? AppColors.textSuccess.withValues(alpha: 0.15)
                  : AppColors.pepsiBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isShort
                  ? Icons.arrow_downward_rounded
                  : isExcess
                  ? Icons.arrow_upward_rounded
                  : Icons.check_circle_outline_rounded,
              color: isShort
                  ? AppColors.pepsiRed
                  : isExcess
                  ? AppColors.textSuccess
                  : AppColors.pepsiBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Final Result',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isShort
                      ? 'SHORT'
                      : isExcess
                      ? 'EXCESS'
                      : 'BALANCED',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isShort
                        ? AppColors.pepsiRed
                        : isExcess
                        ? AppColors.textSuccess
                        : AppColors.pepsiBlue,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(record.finalAmount.abs()),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isShort
                  ? AppColors.pepsiRed
                  : isExcess
                  ? AppColors.textSuccess
                  : AppColors.pepsiBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Shared Builders ==========

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray300.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.pepsiBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isBold ? Colors.black87 : AppColors.gray500,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: valueColor ?? Colors.black87,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ========== Styles ==========

  TextStyle get _tableHeaderStyle => GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.gray500,
  );

  TextStyle get _tableCellStyle => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
  );

  TextStyle get _tableTotalStyle => GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.pepsiBlue,
  );

  // ========== Helpers ==========

  String _formatDateLabel(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, EEEE').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return 'Rs ${formatter.format(amount)}';
  }
}
