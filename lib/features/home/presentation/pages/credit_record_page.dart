import 'package:animations/animations.dart';
import 'package:ch_atta_traders_billing_application/common/themes/color_schemes.dart';
import 'package:ch_atta_traders_billing_application/common/themes/text_styles.dart';
import 'package:ch_atta_traders_billing_application/common/utils/billing_calculations.dart';
import 'package:ch_atta_traders_billing_application/common/utils/string_helpers.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/bill_details_dialog.dart';
import 'package:ch_atta_traders_billing_application/common/widgets/custom_snackbar.dart';
import 'package:ch_atta_traders_billing_application/core/utils/app_preferences.dart';
import 'package:ch_atta_traders_billing_application/core/utils/date_formatters.dart';
import 'package:ch_atta_traders_billing_application/data/models/bill_base.dart';
import 'package:ch_atta_traders_billing_application/data/models/credit_history.dart';
import 'package:ch_atta_traders_billing_application/data/models/sale_history.dart';
import 'package:ch_atta_traders_billing_application/data/repositories/dashboard_repository.dart';
import 'package:ch_atta_traders_billing_application/features/credit/providers/credit_history_provider.dart';
import 'package:ch_atta_traders_billing_application/features/sales/providers/sale_provider.dart';
import 'package:ch_atta_traders_billing_application/services/printer/bill_printer.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_connection_service.dart';
import 'package:ch_atta_traders_billing_application/services/printer/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

/// Displays a list of credit transaction records with delete functionality.
class CreditRecordPage extends StatefulWidget {
  const CreditRecordPage({super.key});

  @override
  State<CreditRecordPage> createState() => _CreditRecordPageState();
}

class _CreditRecordPageState extends State<CreditRecordPage> {
  late final CreditHistoryProvider _creditProvider;
  bool _hasLoadedOnce = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cratesController = TextEditingController();
  int? _completingIndex;
  int? _editingIndex;
  int? _deletingIndex;
  int? _printingIndex;
  bool _hasInternetConnection = true;
  late bool _isPrinterConnected;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final PrinterService _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    _creditProvider = CreditHistoryProvider();
    _creditProvider.addListener(_onCreditsChanged);
    // Immediately use PrinterService state (synchronous - singleton already initialized)
    _isPrinterConnected = _printerService.state.isConnected;
    _initConnectivity();
    _setupConnectivityListener();
    // Listen to printer service changes (more reliable than PrinterConnectionService)
    _printerService.addListener(_onPrinterStateChanged);
    // Also listen to PrinterConnectionService as backup
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

  /// Called when printer service state changes
  void _onPrinterStateChanged() {
    if (mounted) {
      setState(() {
        _isPrinterConnected = _printerService.state.isConnected;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load credits every time the page comes into view
    if (!_hasLoadedOnce || ModalRoute.of(context)?.isCurrent == true) {
      _hasLoadedOnce = true;
      _loadCredits();
      _checkPrinterConnection(); // Recheck printer connection when page is active
    }
  }

  /// Initialize connectivity check on app start
  Future<void> _initConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      setState(() => _hasInternetConnection = false);
    }
  }

  /// Setup listener for connectivity changes
  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _updateConnectionStatus(results);
    });
  }

  /// Update connection status based on connectivity results
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection =
        results.isNotEmpty &&
        !results.every((result) => result == ConnectivityResult.none);

    if (mounted && _hasInternetConnection != hasConnection) {
      setState(() => _hasInternetConnection = hasConnection);

      // Reload data when connection is restored
      if (hasConnection && _hasLoadedOnce) {
        _loadCredits();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cratesController.dispose();
    _creditProvider.removeListener(_onCreditsChanged);
    _creditProvider.dispose();
    _connectivitySubscription?.cancel();
    _printerService.removeListener(_onPrinterStateChanged);
    PrinterConnectionService.instance.removeListener(
      _onPrinterConnectionChanged,
    );
    super.dispose();
  }

  /// Rebuild app bar when credits list changes (for bill count badge)
  void _onCreditsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCredits() async {
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier != null && salesmanIdentifier.isNotEmpty) {
      await _creditProvider.loadAllCreditHistory(salesmanIdentifier);
    }
  }

  Future<void> _refreshCredits() async {
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier != null && salesmanIdentifier.isNotEmpty) {
      await _creditProvider.refreshCreditHistory(salesmanIdentifier);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _creditProvider,
      child: Scaffold(
        backgroundColor: AppColors.gray100,
        appBar: _buildAppBar(),
        body: !_hasInternetConnection
            ? _buildNoInternetState()
            : Consumer<CreditHistoryProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.credits.isEmpty) {
                    return _buildLoadingState();
                  }

                  if (provider.hasError) {
                    return _buildErrorState(provider.errorMessage);
                  }

                  if (provider.credits.isEmpty && !provider.isLoading) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshCredits,
                    color: AppColors.pepsiBlue,
                    child: _buildBillList(provider.credits),
                  );
                },
              ),
      ),
    );
  }

  // ========== Business Logic Methods ==========

  Future<void> _markBillComplete(
    int index,
    List<CreditHistory> billHistory,
  ) async {
    if (!_isValidIndex(index, billHistory)) return;

    setState(() => _completingIndex = index);

    final deletedBill = billHistory[index];

    // Get salesman identifier from shared preferences
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
      setState(() => _completingIndex = null);
      _showErrorSnackBar('Salesman identifier not found. Please log in again.');
      return;
    }

    // Convert CreditHistory to SaleHistory
    final saleHistory = SaleHistory(
      billId: deletedBill.billId,
      customerName: deletedBill.customerName,
      date: deletedBill.date,
      products: deletedBill.products,
      discount: deletedBill.discount,
      billType: BillType.credit,
    );

    // Save to sale history using SaleProvider
    // Use saveSaleFromCreditConversion to avoid double-counting customers
    final saleProvider = SaleProvider();
    final savedAsSale = await saleProvider.saveSaleFromCreditConversion(
      saleHistory,
      salesmanIdentifier,
    );

    if (!savedAsSale) {
      setState(() => _completingIndex = null);
      _showErrorSnackBar(
        'Failed to save as sale history. Operation cancelled.',
      );
      return;
    }

    // Update dashboard summary if bill is from today
    final today = DateTime.now();
    final billDate = deletedBill.date;
    final isTodaysBill =
        billDate.year == today.year &&
        billDate.month == today.month &&
        billDate.day == today.day;

    final dashboardRepo = DashboardRepository();

    if (isTodaysBill) {
      final summaryUpdated = await dashboardRepo.updateSummaryOnCreditToSale(
        salesmanName: salesmanIdentifier,
        date: deletedBill.date,
        amountDue: deletedBill.amountDue,
        cratesDue: deletedBill.cratesDue,
        isPaidBill: deletedBill
            .isPaid, // Pass whether bill was already paid (cash with MT)
      );

      if (!summaryUpdated) {
        setState(() => _completingIndex = null);
        _showErrorSnackBar('Failed to update dashboard. Operation cancelled.');
        return;
      }
    } else {
      // Previous day bill - update today's previous day collection
      await dashboardRepo.updateSummaryForPreviousDayCollection(
        salesmanName: salesmanIdentifier,
        cashReceived: deletedBill.isPaid ? null : deletedBill.amountDue,
        cratesReceived: deletedBill.cratesDue,
      );
    }

    // Delete from credit history using CreditHistoryProvider
    final deletedFromCredit = await _creditProvider.deleteCreditRecord(
      billId: deletedBill.billId,
      salesmanName: salesmanIdentifier,
    );

    if (deletedFromCredit) {
      _showCompletionSnackBar(deletedBill.customerName);
    } else {
      _showErrorSnackBar('Failed to complete operation.');
    }

    setState(() => _completingIndex = null);
  }

  /// Marks a credit bill as complete and prints a payment receipt
  Future<void> _markBillCompleteAndPrint(
    int index,
    List<CreditHistory> billHistory,
  ) async {
    if (!_isValidIndex(index, billHistory)) return;

    setState(() => _printingIndex = index);

    final deletedBill = billHistory[index];

    // Get salesman identifier from shared preferences
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
      setState(() => _printingIndex = null);
      _showErrorSnackBar('Salesman identifier not found. Please log in again.');
      return;
    }

    // Calculate amount received (grand total - discount)
    // Amount received is the amount due (what was still owed), not the full bill amount
    // This correctly handles cases where partial payments were already made
    final amountReceived = deletedBill.amountDue;

    // Calculate previously paid amount (net amount - amount due)
    final grandTotal = BillingCalculations.calculateGrandTotal(
      deletedBill.products,
    );
    final netAmount = grandTotal - deletedBill.discount;
    final previouslyPaid = netAmount - deletedBill.amountDue;

    // Calculate crates information
    final totalCrates = BillingCalculations.calculateTotalCrates(
      deletedBill.products,
    );
    final cratesReceived = deletedBill.cratesDue; // Crates being returned now
    final previouslyReturnedCrates = totalCrates - deletedBill.cratesDue;

    // Convert CreditHistory to SaleHistory
    final saleHistory = SaleHistory(
      billId: deletedBill.billId,
      customerName: deletedBill.customerName,
      date: deletedBill.date,
      products: deletedBill.products,
      discount: deletedBill.discount,
      billType: BillType.credit,
    );

    // Save to sale history using SaleProvider
    final saleProvider = SaleProvider();
    final savedAsSale = await saleProvider.saveSaleFromCreditConversion(
      saleHistory,
      salesmanIdentifier,
    );

    if (!savedAsSale) {
      setState(() => _printingIndex = null);
      _showErrorSnackBar(
        'Failed to save as sale history. Operation cancelled.',
      );
      return;
    }

    // Update dashboard summary if bill is from today
    final today = DateTime.now();
    final billDate = deletedBill.date;
    final isTodaysBill =
        billDate.year == today.year &&
        billDate.month == today.month &&
        billDate.day == today.day;

    final dashboardRepo = DashboardRepository();

    if (isTodaysBill) {
      final summaryUpdated = await dashboardRepo.updateSummaryOnCreditToSale(
        salesmanName: salesmanIdentifier,
        date: deletedBill.date,
        amountDue: deletedBill.amountDue,
        cratesDue: deletedBill.cratesDue,
        isPaidBill: deletedBill.isPaid,
      );

      if (!summaryUpdated) {
        setState(() => _printingIndex = null);
        _showErrorSnackBar('Failed to update dashboard. Operation cancelled.');
        return;
      }
    } else {
      // Previous day bill - update today's previous day collection
      await dashboardRepo.updateSummaryForPreviousDayCollection(
        salesmanName: salesmanIdentifier,
        cashReceived: deletedBill.isPaid ? null : deletedBill.amountDue,
        cratesReceived: deletedBill.cratesDue,
      );
    }

    // Delete from credit history
    final deletedFromCredit = await _creditProvider.deleteCreditRecord(
      billId: deletedBill.billId,
      salesmanName: salesmanIdentifier,
    );

    if (!deletedFromCredit) {
      setState(() => _printingIndex = null);
      _showErrorSnackBar('Failed to complete operation.');
      return;
    }

    // Print the payment receipt
    final printResult = await BillPrinter.printPaymentReceipt(
      billId: deletedBill.billId,
      customerName: deletedBill.customerName,
      originalBillDate: deletedBill.date,
      amountReceived: amountReceived,
      salesmanName: salesmanIdentifier,
      products: deletedBill.products,
      discount: deletedBill.discount,
      previouslyPaid: previouslyPaid > 0 ? previouslyPaid : null,
      cratesReceived: cratesReceived,
      previouslyReturnedCrates: previouslyReturnedCrates > 0
          ? previouslyReturnedCrates
          : null,
    );

    if (!mounted) {
      return;
    }

    if (printResult.success) {
      _showCompletionSnackBar(deletedBill.customerName);
    } else {
      // Bill was marked complete but print failed
      CustomSnackBar.show(
        context,
        message: 'Bill completed but print failed: ${printResult.errorMessage}',
        type: SnackBarType.warning,
      );
    }

    setState(() => _printingIndex = null);
  }

  bool _isValidIndex(int index, List<CreditHistory> billHistory) {
    return index >= 0 && index < billHistory.length;
  }

  Future<void> _deleteBillPermanently(
    int index,
    List<CreditHistory> billHistory,
  ) async {
    if (!_isValidIndex(index, billHistory)) return;

    setState(() => _deletingIndex = index);

    final billToDelete = billHistory[index];

    // Get salesman identifier from shared preferences
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
      setState(() => _deletingIndex = null);
      _showErrorSnackBar('Salesman identifier not found. Please log in again.');
      return;
    }

    try {
      // Save to delete history
      final formattedDate = DateFormatters.formatForDeleteHistory(
        billToDelete.date,
      );
      final deleteHistoryPath =
          'Deleted History/$salesmanIdentifier/$formattedDate/${billToDelete.billId}';

      // Use CreditHistoryProvider's deleteCreditRecordToHistory method
      final savedToDeleteHistory = await _creditProvider
          .saveCreditToDeleteHistory(
            path: deleteHistoryPath,
            credit: billToDelete,
          );

      if (!savedToDeleteHistory) {
        setState(() => _deletingIndex = null);
        _showErrorSnackBar(
          'Failed to save to delete history. Operation cancelled.',
        );
        return;
      }

      // Update dashboard summary if bill is from today
      final today = DateTime.now();
      final billDate = billToDelete.date;
      final isTodaysBill =
          billDate.year == today.year &&
          billDate.month == today.month &&
          billDate.day == today.day;

      if (isTodaysBill) {
        // Calculate items sold for dashboard update
        final itemsSold = billToDelete.products.fold<int>(
          0,
          (sum, p) => sum + p.quantity,
        );

        final dashboardRepo = DashboardRepository();
        final summaryUpdated = await dashboardRepo.updateSummaryOnCreditDelete(
          salesmanName: salesmanIdentifier,
          date: billToDelete.date,
          amountDue: billToDelete.amountDue,
          cratesDue: billToDelete.cratesDue,
          itemsSold: itemsSold,
          discount: billToDelete.discount,
          isPaidBill: billToDelete.isPaid,
        );

        if (!summaryUpdated) {
          setState(() => _deletingIndex = null);
          _showErrorSnackBar(
            'Failed to update dashboard. Operation cancelled.',
          );
          return;
        }
      }

      // Delete from credit history
      final deletedFromCredit = await _creditProvider.deleteCreditRecord(
        billId: billToDelete.billId,
        salesmanName: salesmanIdentifier,
      );

      if (!mounted) return;

      if (deletedFromCredit) {
        CustomSnackBar.show(
          context,
          message: 'Bill deleted.',
          type: SnackBarType.success,
        );
      } else {
        _showErrorSnackBar('Failed to delete from credit records.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error deleting bill: ${e.toString()}');
      }
    }

    if (mounted) {
      setState(() => _deletingIndex = null);
    }
  }

  void _showCompleteConfirmation(int index, List<CreditHistory> billHistory) {
    final bill = billHistory[index];
    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) =>
          _buildCompleteConfirmationDialog(bill, index, billHistory),
    );
  }

  void _showFullPaymentConfirmation(
    int index,
    List<CreditHistory> billHistory,
  ) {
    final bill = billHistory[index];
    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) =>
          _buildFullPaymentConfirmationDialog(bill, index, billHistory),
    );
  }

  void _showDeleteConfirmation(int index, List<CreditHistory> billHistory) {
    final bill = billHistory[index];
    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) =>
          _buildDeleteConfirmationDialog(bill, index, billHistory),
    );
  }

  void _showEditDialog(int index, List<CreditHistory> billHistory) {
    final bill = billHistory[index];
    _amountController.clear();
    _cratesController.clear();
    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) => _buildEditDialog(bill, index, billHistory),
    );
  }

  Future<void> _updateBillRecord(
    int index,
    int? amountReceived,
    int? cratesReceived,
    List<CreditHistory> billHistory,
  ) async {
    if (!_isValidIndex(index, billHistory)) return;

    setState(() => _editingIndex = index);

    final bill = billHistory[index];
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);
    // Net total accounts for discount - this is what the customer actually owes
    final netTotal = grandTotal - bill.discount;

    // Calculate new amount due
    int? newAmountDue;
    bool? isPaid;
    bool isFullyPaid = false;
    if (amountReceived != null && amountReceived > 0) {
      // Check if payment covers the remaining amount due
      if (amountReceived >= bill.amountDue) {
        // Fully paid - set amountDue to 0
        newAmountDue = 0;
        isPaid = true;
        isFullyPaid = true;
      } else {
        // Partial payment - subtract from current amountDue
        newAmountDue = bill.amountDue - amountReceived;
        isPaid = false;
      }
    }

    // Calculate new crates due
    int? newCratesDue;
    bool isAllCratesReturned = false;
    if (cratesReceived != null && cratesReceived > 0) {
      final calculatedCrates = (bill.cratesDue - cratesReceived).clamp(
        0,
        bill.cratesDue,
      );
      newCratesDue = calculatedCrates;
      if (calculatedCrates == 0) {
        isAllCratesReturned = true;
      }
    }

    // Get salesman identifier from shared preferences
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
      setState(() => _editingIndex = null);
      _showErrorSnackBar('Unable to get salesman information');
      return;
    }

    // Check if both amount and crates are fully cleared
    // Use netTotal (with discount) for comparison since amountDue was stored with discount applied
    final wasAmountFullyPaid =
        isFullyPaid || (bill.isPaid && bill.amountDue == netTotal);
    final wereCratesFullyReturned = isAllCratesReturned || bill.cratesDue == 0;

    if (wasAmountFullyPaid && wereCratesFullyReturned) {
      // Save to sale history and delete from credit
      final saleHistory = SaleHistory(
        billId: bill.billId,
        customerName: bill.customerName,
        date: bill.date,
        products: bill.products,
        discount: bill.discount,
        billType: BillType.credit,
      );

      // Save to sale history using SaleProvider
      // Use saveSaleFromCreditConversion to avoid double-counting customers
      final saleProvider = SaleProvider();
      final savedAsSale = await saleProvider.saveSaleFromCreditConversion(
        saleHistory,
        salesmanIdentifier,
      );

      if (!savedAsSale) {
        setState(() => _editingIndex = null);
        _showErrorSnackBar('Failed to save as sale history. Update cancelled.');
        return;
      }

      // Update dashboard summary if bill is from today
      final today = DateTime.now();
      final billDate = bill.date;
      final isTodaysBill =
          billDate.year == today.year &&
          billDate.month == today.month &&
          billDate.day == today.day;

      final dashboardRepo = DashboardRepository();

      if (isTodaysBill) {
        final summaryUpdated = await dashboardRepo.updateSummaryOnCreditToSale(
          salesmanName: salesmanIdentifier,
          date: bill.date,
          amountDue: bill.amountDue,
          cratesDue: bill.cratesDue,
          isPaidBill:
              bill.isPaid, // Pass whether bill was already paid (cash with MT)
        );

        if (!summaryUpdated) {
          setState(() => _editingIndex = null);
          _showErrorSnackBar('Failed to update dashboard. Update cancelled.');
          return;
        }
      } else {
        // Previous day bill - update today's previous day collection
        await dashboardRepo.updateSummaryForPreviousDayCollection(
          salesmanName: salesmanIdentifier,
          cashReceived: bill.isPaid ? null : bill.amountDue,
          cratesReceived: bill.cratesDue,
        );
      }

      // Delete from credit history using CreditHistoryProvider
      final deletedFromCredit = await _creditProvider.deleteCreditRecord(
        billId: bill.billId,
        salesmanName: salesmanIdentifier,
      );

      if (!mounted) return;

      if (deletedFromCredit) {
        CustomSnackBar.show(
          context,
          message: 'Payment completed! Record moved to sales',
          type: SnackBarType.success,
        );
      } else {
        _showErrorSnackBar('Failed to delete from credit records.');
      }

      setState(() => _editingIndex = null);
    } else {
      // Partial payment - check if bill is from today
      final today = DateTime.now();
      final billDate = bill.date;
      final isTodaysBill =
          billDate.year == today.year &&
          billDate.month == today.month &&
          billDate.day == today.day;

      // Update dashboard summary
      final dashboardRepo = DashboardRepository();

      if (isTodaysBill) {
        final summaryUpdated = await dashboardRepo
            .updateSummaryOnPartialPayment(
              salesmanName: salesmanIdentifier,
              date: bill.date,
              cashReceived: amountReceived,
              cratesReceived: cratesReceived,
              isPaidBill: bill
                  .isPaid, // Pass whether bill was already paid (cash with MT)
            );

        if (!summaryUpdated) {
          setState(() => _editingIndex = null);
          _showErrorSnackBar('Failed to update dashboard. Update cancelled.');
          return;
        }
      } else {
        // Previous day bill - update today's previous day collection
        await dashboardRepo.updateSummaryForPreviousDayCollection(
          salesmanName: salesmanIdentifier,
          cashReceived: bill.isPaid ? null : amountReceived,
          cratesReceived: cratesReceived,
        );
      }

      // Update in Firebase using provider
      final success = await _creditProvider.updateCreditBalance(
        salesmanName: salesmanIdentifier,
        credit: bill,
        newAmountDue: newAmountDue,
        newCratesDue: newCratesDue,
        isPaid: isPaid,
        isRecordUpdated: true,
      );

      if (success) {
        _showUpdateSnackBar(amountReceived, cratesReceived);
      } else {
        _showErrorSnackBar('Failed to update record');
      }

      setState(() => _editingIndex = null);
    }
  }

  /// Updates a bill record and prints a partial payment receipt
  Future<void> _updateBillRecordAndPrint(
    int index,
    int? amountReceived,
    int? cratesReceived,
    List<CreditHistory> billHistory,
  ) async {
    if (!_isValidIndex(index, billHistory)) return;

    setState(() => _editingIndex = index);

    final bill = billHistory[index];
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);
    // Net total accounts for discount - this is what the customer actually owes
    final netTotal = grandTotal - bill.discount;
    final totalCrates = BillingCalculations.calculateTotalCrates(bill.products);

    // Calculate new amount due
    int? newAmountDue;
    bool? isPaid;
    bool isFullyPaid = false;
    if (amountReceived != null && amountReceived > 0) {
      if (amountReceived >= bill.amountDue) {
        newAmountDue = 0;
        isPaid = true;
        isFullyPaid = true;
      } else {
        newAmountDue = bill.amountDue - amountReceived;
        isPaid = false;
      }
    }

    // Calculate new crates due
    int? newCratesDue;
    bool isAllCratesReturned = false;
    if (cratesReceived != null && cratesReceived > 0) {
      if (cratesReceived >= bill.cratesDue) {
        newCratesDue = 0;
        isAllCratesReturned = true;
      } else {
        newCratesDue = bill.cratesDue - cratesReceived;
      }
    }

    // Get salesman identifier from shared preferences
    final salesmanIdentifier = await AppPreferences.instance.salesmanIdentifier;
    if (salesmanIdentifier == null || salesmanIdentifier.isEmpty) {
      setState(() => _editingIndex = null);
      _showErrorSnackBar('Salesman identifier not found. Please log in again.');
      return;
    }

    // Check if both amount and crates are fully cleared
    // Use netTotal (with discount) for comparison since amountDue was stored with discount applied
    final wasAmountFullyPaid =
        isFullyPaid || (bill.isPaid && bill.amountDue == netTotal);
    final wereCratesFullyReturned = isAllCratesReturned || bill.cratesDue == 0;

    if (wasAmountFullyPaid && wereCratesFullyReturned) {
      // Convert to SaleHistory
      final saleHistory = SaleHistory(
        billId: bill.billId,
        customerName: bill.customerName,
        date: bill.date,
        products: bill.products,
        discount: bill.discount,
        billType: BillType.credit,
      );

      // Save to sale history
      final saleProvider = SaleProvider();
      final savedAsSale = await saleProvider.saveSaleFromCreditConversion(
        saleHistory,
        salesmanIdentifier,
      );

      if (!savedAsSale) {
        setState(() => _editingIndex = null);
        _showErrorSnackBar(
          'Failed to save as sale history. Operation cancelled.',
        );
        return;
      }

      // Update dashboard
      final today = DateTime.now();
      final billDate = bill.date;
      final isTodaysBill =
          billDate.year == today.year &&
          billDate.month == today.month &&
          billDate.day == today.day;

      final dashboardRepo = DashboardRepository();

      if (isTodaysBill) {
        // Only call credit-to-sale conversion (which handles the full amount)
        // Do NOT call partial payment update here to avoid double counting
        await dashboardRepo.updateSummaryOnCreditToSale(
          salesmanName: salesmanIdentifier,
          date: bill.date,
          amountDue: bill.amountDue, // Use ORIGINAL amountDue, not newAmountDue
          cratesDue: bill.cratesDue, // Use ORIGINAL cratesDue, not newCratesDue
          isPaidBill: bill.isPaid,
        );
      } else {
        // Previous day bill - update today's previous day collection
        await dashboardRepo.updateSummaryForPreviousDayCollection(
          salesmanName: salesmanIdentifier,
          cashReceived: bill.isPaid ? null : bill.amountDue,
          cratesReceived: bill.cratesDue,
        );
      }

      // Delete from credit history
      final deletedFromCredit = await _creditProvider.deleteCreditRecord(
        billId: bill.billId,
        salesmanName: salesmanIdentifier,
      );

      if (!deletedFromCredit) {
        setState(() => _editingIndex = null);
        _showErrorSnackBar('Failed to complete operation.');
        return;
      }

      // Print receipt
      if (amountReceived != null && amountReceived > 0 ||
          cratesReceived != null && cratesReceived > 0) {
        final printResult = await BillPrinter.printPartialPaymentReceipt(
          billId: bill.billId,
          customerName: bill.customerName,
          originalBillDate: bill.date,
          billTotal: netTotal, // Use netTotal (with discount) for consistency
          amountDue: bill.amountDue,
          amountReceived: amountReceived ?? 0,
          totalCrates: totalCrates,
          cratesDue: bill.cratesDue,
          cratesReceived: cratesReceived ?? 0,
          products: bill.products,
        );

        if (!mounted) return;

        if (printResult.success) {
          _showCompletionSnackBar(bill.customerName);
        } else {
          CustomSnackBar.show(
            context,
            message:
                'Bill completed but print failed: ${printResult.errorMessage}',
            type: SnackBarType.warning,
          );
        }
      } else {
        _showCompletionSnackBar(bill.customerName);
      }

      setState(() => _editingIndex = null);
    } else {
      // Update credit balance
      final updated = await _creditProvider.updateCreditBalance(
        salesmanName: salesmanIdentifier,
        credit: bill,
        newAmountDue: newAmountDue,
        newCratesDue: newCratesDue,
        isPaid: isPaid,
        isRecordUpdated: true,
      );

      if (!updated) {
        setState(() => _editingIndex = null);
        _showErrorSnackBar('Failed to update credit record.');
        return;
      }

      // Check if bill is from today for dashboard update
      final today = DateTime.now();
      final billDate = bill.date;
      final isTodaysBillForPartial =
          billDate.year == today.year &&
          billDate.month == today.month &&
          billDate.day == today.day;

      // Update dashboard
      final dashboardRepo = DashboardRepository();

      if (isTodaysBillForPartial) {
        await dashboardRepo.updateSummaryOnPartialPayment(
          salesmanName: salesmanIdentifier,
          date: bill.date,
          cashReceived: amountReceived,
          cratesReceived: cratesReceived,
          isPaidBill: bill.isPaid,
        );
      } else {
        // Previous day bill - update today's previous day collection
        await dashboardRepo.updateSummaryForPreviousDayCollection(
          salesmanName: salesmanIdentifier,
          cashReceived: bill.isPaid ? null : amountReceived,
          cratesReceived: cratesReceived,
        );
      }

      // Print receipt
      final printResult = await BillPrinter.printPartialPaymentReceipt(
        billId: bill.billId,
        customerName: bill.customerName,
        originalBillDate: bill.date,
        billTotal: netTotal, // Use netTotal (with discount) for consistency
        amountDue: bill.amountDue,
        amountReceived: amountReceived ?? 0,
        totalCrates: totalCrates,
        cratesDue: bill.cratesDue,
        cratesReceived: cratesReceived ?? 0,
        products: bill.products,
      );

      if (!mounted) return;

      if (printResult.success) {
        _showUpdateSnackBar(amountReceived, cratesReceived);
      } else {
        CustomSnackBar.show(
          context,
          message: 'Updated but print failed: ${printResult.errorMessage}',
          type: SnackBarType.warning,
        );
      }

      setState(() => _editingIndex = null);
    }
  }

  void _showUpdateSnackBar(int? amountReceived, int? cratesReceived) {
    String message;
    final hasAmount = amountReceived != null && amountReceived > 0;
    final hasCrates = cratesReceived != null && cratesReceived > 0;

    if (hasAmount && hasCrates) {
      message = 'Payment and crates received, record updated';
    } else if (hasAmount) {
      message = 'Payment received and record updated';
    } else if (hasCrates) {
      message = 'Crates received and record updated';
    } else {
      message = 'Record updated';
    }

    CustomSnackBar.show(context, message: message, type: SnackBarType.success);
  }

  void _showErrorSnackBar(String message) {
    CustomSnackBar.show(context, message: message, type: SnackBarType.error);
  }

  void _showCompletionSnackBar(String customerName) {
    CustomSnackBar.show(
      context,
      message: 'Bill marked as paid and moved to sales',
      type: SnackBarType.success,
    );
  }

  void _showBillDetails(CreditHistory bill) {
    showModal<void>(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        transitionDuration: Duration(milliseconds: 300),
        reverseTransitionDuration: Duration(milliseconds: 200),
      ),
      builder: (context) =>
          BillDetailsDialog(bill: bill, accentColor: AppColors.pepsiRedLight),
    );
  }

  // ========== Main UI Building Methods ==========

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.pepsiWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text('Credit History', style: AppTextStyles.pageTitleBlack),
      centerTitle: false,
      actions: [
        if (_creditProvider.credits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pepsiRedLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.credit_card_outlined,
                      size: 15,
                      color: AppColors.pepsiRedLight,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_creditProvider.credits.length} Bills',
                      style: TextStyle(
                        color: AppColors.pepsiRedLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.gray300, height: 1),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.pepsiBlue),
    );
  }

  Widget _buildErrorState(String? errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.pepsiRedLight.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.pepsiRedLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Credits',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Something went wrong',
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCredits,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pepsiBlue,
                foregroundColor: AppColors.pepsiWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.pepsiRedLight.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.credit_card_outlined,
                size: 48,
                color: AppColors.pepsiRedLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Credit Records',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Credit transactions will appear here',
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.pepsiRed, AppColors.pepsiRedLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pepsiRed.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _refreshCredits,
                icon: const Icon(Icons.refresh_rounded, size: 22),
                label: const Text(
                  'Refresh List',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.pepsiWhite,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoInternetState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.pepsiBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_outlined,
                size: 48,
                color: AppColors.pepsiBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Internet Connection',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for connection. Will update automatically when restored.',
              style: AppTextStyles.helperText.copyWith(
                color: AppColors.gray500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillList(List<CreditHistory> billHistory) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: billHistory.length,
      itemBuilder: (context, index) {
        final bill = billHistory[index];
        return _buildCreditCard(bill, index, billHistory);
      },
    );
  }

  // ========== Card Building Methods ==========

  Widget _buildCreditCard(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.pepsiWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gray300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showBillDetails(bill),
                    borderRadius: BorderRadius.circular(8),
                    child: _buildCardContent(bill),
                  ),
                ),
                const SizedBox(width: 12),
                _buildActionButtons(bill, index, billHistory),
              ],
            ),
            // Print Receipt (only show spacing + button when printer connected)
            if (_isPrinterConnected) ...[
              const SizedBox(height: 12),
              _buildPrintReceiptButton(index, billHistory),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrintReceiptButton(int index, List<CreditHistory> billHistory) {
    final isEditLoading = _editingIndex == index;
    final isCompletingLoading = _completingIndex == index;
    final isDeletingLoading = _deletingIndex == index;
    final isPrintingLoading = _printingIndex == index;
    final isAnyLoading =
        isEditLoading ||
        isCompletingLoading ||
        isDeletingLoading ||
        isPrintingLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAnyLoading || !_isPrinterConnected
            ? null
            : () => _showFullPaymentConfirmation(index, billHistory),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: isPrintingLoading ? 48 : 39,
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(
              alpha: (isAnyLoading || !_isPrinterConnected) ? 0.05 : 0.1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: isPrintingLoading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Printing...',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 14,
                          color: Colors.green.withValues(
                            alpha: (isAnyLoading || !_isPrinterConnected)
                                ? 0.4
                                : 1.0,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: Colors.green.withValues(
                          alpha: (isAnyLoading || !_isPrinterConnected)
                              ? 0.4
                              : 1.0,
                        ),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Print Receipt',
                        style: AppTextStyles.helperText.copyWith(
                          fontSize: 14,
                          color: Colors.green.withValues(
                            alpha: (isAnyLoading || !_isPrinterConnected)
                                ? 0.4
                                : 1.0,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(CreditHistory bill) {
    final totalItems = BillingCalculations.calculateTotalItems(bill.products);
    final formattedDate = DateFormat('d-MMM').format(bill.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCustomerName(bill.customerName),
        const SizedBox(height: 6),
        _buildDateTimeInfo(formattedDate, bill.formattedTime),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAmountText(bill.amountDue, bill.isPaid),
            const SizedBox(width: 8),
            _buildItemCountBadge(totalItems),
          ],
        ),
        if (bill.cratesDue > 0) ...[
          const SizedBox(height: 6),
          _buildPendingCratesText(bill.cratesDue),
        ],
      ],
    );
  }

  Widget _buildCustomerName(String name) {
    return Text(
      toTitleCase(name),
      style: AppTextStyles.productItemName.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.25,
      ),
    );
  }

  Widget _buildDateTimeInfo(String date, String time) {
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.gray500),
        const SizedBox(width: 4),
        Text(
          '$date • $time',
          style: AppTextStyles.helperText.copyWith(
            fontSize: 12,
            color: AppColors.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountText(int amount, bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid
            ? Colors.green[50]
            : AppColors.pepsiRedLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPaid) ...[
            Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
            const SizedBox(width: 6),
          ],
          Text(
            isPaid && amount == 0 ? 'Paid' : 'Rs. ${formatCashAmount(amount)}',
            style: AppTextStyles.productItemTotal.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: isPaid ? Colors.green[700] : AppColors.pepsiRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCratesText(int cratesDue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange[300]!, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: Colors.orange[700]),
          const SizedBox(width: 6),
          Text(
            'Pending: $cratesDue crates',
            style: AppTextStyles.productItemTotal.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gray300, width: 0.5),
      ),
      child: Text(
        '$count items',
        style: AppTextStyles.helperText.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.gray500,
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
    final isEditLoading = _editingIndex == index;
    final isCompletingLoading = _completingIndex == index;
    final isDeletingLoading = _deletingIndex == index;
    final isPrintingLoading = _printingIndex == index;
    final isAnyLoading =
        isEditLoading ||
        isCompletingLoading ||
        isDeletingLoading ||
        isPrintingLoading;

    // Disable delete when record has been updated
    final isDeleteDisabled = bill.isRecordUpdated || isAnyLoading;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isAnyLoading
                    ? null
                    : () => _showEditDialog(index, billHistory),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.pepsiBlueLight.withValues(
                      alpha: isAnyLoading ? 0.05 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isEditLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.pepsiBlueLight,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.edit_outlined,
                          color: AppColors.pepsiBlueLight.withValues(
                            alpha: isAnyLoading ? 0.4 : 1.0,
                          ),
                          size: 20,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDeleteDisabled
                    ? null
                    : () => _showDeleteConfirmation(index, billHistory),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.pepsiRedLight.withValues(
                      alpha: isAnyLoading ? 0.05 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isDeletingLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.pepsiRedLight,
                            ),
                          ),
                        )
                      : Icon(
                          bill.isRecordUpdated
                              ? Icons.block
                              : Icons.delete_outline,
                          color: AppColors.pepsiRedLight.withValues(
                            alpha: isDeleteDisabled ? 0.4 : 1.0,
                          ),
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 88,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isAnyLoading
                  ? null
                  : () => _showCompleteConfirmation(index, billHistory),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(
                    alpha: isAnyLoading ? 0.05 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isCompletingLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.check_circle,
                          color: Colors.green.withValues(
                            alpha: isAnyLoading ? 0.4 : 1.0,
                          ),
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== Dialog Building Methods ==========

  Dialog _buildCompleteConfirmationDialog(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
    return Dialog(
      backgroundColor: AppColors.pepsiWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCompleteIcon(),
            const SizedBox(height: 20),
            _buildCompleteTitle(),
            const SizedBox(height: 12),
            _buildCompleteMessage(bill.customerName),
            const SizedBox(height: 24),
            _buildCompleteDialogActions(index, billHistory),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.check, color: Colors.green[600], size: 32),
    );
  }

  Widget _buildCompleteTitle() {
    return Text(
      'Mark as Paid?',
      style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
    );
  }

  Widget _buildCompleteMessage(String customerName) {
    final formattedName = toTitleCase(customerName);
    return Text(
      'Mark $formattedName\'s bill as fully paid? This will move the record from credit to sales history.',
      textAlign: TextAlign.center,
      style: AppTextStyles.helperText.copyWith(
        color: AppColors.gray500,
        fontSize: 14,
      ),
    );
  }

  Widget _buildCompleteDialogActions(
    int index,
    List<CreditHistory> billHistory,
  ) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.gray300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
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
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _markBillComplete(index, billHistory);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: AppColors.pepsiWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Paid',
                style: AppTextStyles.smallButton.copyWith(
                  color: AppColors.pepsiWhite,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Dialog _buildFullPaymentConfirmationDialog(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
    return Dialog(
      backgroundColor: AppColors.pepsiWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long,
                color: Colors.green[600],
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Paid in Full?',
              style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'Mark ${toTitleCase(bill.customerName)}\'s bill as fully paid and print receipt? This will move the record from credit to sales history.',
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
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.gray300,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
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
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _markBillCompleteAndPrint(index, billHistory);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: AppColors.pepsiWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Print',
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
    );
  }

  Dialog _buildDeleteConfirmationDialog(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
    return Dialog(
      backgroundColor: AppColors.pepsiWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDeleteIcon(),
            const SizedBox(height: 20),
            _buildDeleteTitle(),
            const SizedBox(height: 12),
            _buildDeleteMessage(bill.customerName),
            const SizedBox(height: 24),
            _buildDeleteDialogActions(index, billHistory),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.pepsiRedLight.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.delete_outline,
        color: AppColors.pepsiRedLight,
        size: 32,
      ),
    );
  }

  Widget _buildDeleteTitle() {
    return Text(
      'Delete Bill?',
      style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
    );
  }

  Widget _buildDeleteMessage(String customerName) {
    final formattedName = toTitleCase(customerName);
    return Text(
      'Permanently delete $formattedName\'s bill? This will remove it from credit history and save it to delete history.',
      textAlign: TextAlign.center,
      style: AppTextStyles.helperText.copyWith(
        color: AppColors.gray500,
        fontSize: 14,
      ),
    );
  }

  Widget _buildDeleteDialogActions(int index, List<CreditHistory> billHistory) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.gray300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancel',
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
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteBillPermanently(index, billHistory);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pepsiRedLight,
                foregroundColor: AppColors.pepsiWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Delete',
                style: AppTextStyles.smallButton.copyWith(
                  color: AppColors.pepsiWhite,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========== Edit Dialog Methods ==========

  Widget _buildEditDialog(
    CreditHistory bill,
    int index,
    List<CreditHistory> billHistory,
  ) {
    final totalCrates = BillingCalculations.calculateTotalCrates(bill.products);
    final grandTotal = BillingCalculations.calculateGrandTotal(bill.products);
    final hasPendingAmount = bill.amountDue > 0 && !bill.isPaid;
    final hasPendingCrates = bill.cratesDue > 0;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        int? enteredAmount = int.tryParse(_amountController.text);
        int? enteredCrates = int.tryParse(_cratesController.text);

        // Check if user has entered values
        final hasEnteredAmount = enteredAmount != null && enteredAmount > 0;
        final hasEnteredCrates = enteredCrates != null && enteredCrates > 0;

        // Cap entered amount to amountDue
        int displayRemainingAmount = bill.amountDue;
        if (hasEnteredAmount) {
          int cappedAmount = enteredAmount > bill.amountDue
              ? bill.amountDue
              : enteredAmount;
          displayRemainingAmount = bill.amountDue - cappedAmount;
        }

        // Cap entered crates to cratesDue
        int displayRemainingCrates = bill.cratesDue;
        if (hasEnteredCrates) {
          int cappedCrates = enteredCrates > bill.cratesDue
              ? bill.cratesDue
              : enteredCrates;
          displayRemainingCrates = bill.cratesDue - cappedCrates;
        }

        return Dialog(
          backgroundColor: AppColors.pepsiWhite,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildEditIcon(),
                  const SizedBox(height: 20),
                  _buildEditTitle(),
                  const SizedBox(height: 8),
                  _buildCustomerNameText(bill.customerName),
                  const SizedBox(height: 24),
                  if (hasPendingAmount)
                    ..._buildEditAmountSection(
                      setDialogState,
                      grandTotal,
                      bill.amountDue,
                      displayRemainingAmount,
                      hasEnteredAmount,
                    ),
                  if (hasPendingAmount && hasPendingCrates) ...[
                    const SizedBox(height: 16),
                    Divider(color: AppColors.gray300),
                    const SizedBox(height: 16),
                  ],
                  if (hasPendingCrates)
                    ..._buildEditCratesSection(
                      setDialogState,
                      totalCrates,
                      bill.cratesDue,
                      displayRemainingCrates,
                      hasEnteredCrates,
                    ),
                  const SizedBox(height: 24),
                  _buildEditDialogActions(
                    index,
                    hasPendingAmount || hasPendingCrates,
                    billHistory,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditIcon() {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.pepsiBlueLight.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.edit_outlined,
        color: AppColors.pepsiBlueLight,
        size: 32,
      ),
    );
  }

  Widget _buildEditTitle() {
    return Text(
      'Update Record',
      style: AppTextStyles.pageTitleBlack.copyWith(fontSize: 20),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCustomerNameText(String customerName) {
    return Text(
      toTitleCase(customerName),
      style: AppTextStyles.productItemName.copyWith(
        fontSize: 16,
        color: AppColors.gray500,
      ),
      textAlign: TextAlign.center,
    );
  }

  List<Widget> _buildEditAmountSection(
    StateSetter setDialogState,
    int grandTotal,
    int amountDue,
    int displayRemainingAmount,
    bool hasEnteredAmount,
  ) {
    final showAmountDue = grandTotal != amountDue;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300, width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Bill Total:',
                  style: AppTextStyles.helperText.copyWith(
                    fontSize: 13,
                    color: AppColors.gray500,
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs. ${formatCashAmount(grandTotal)}',
                  style: AppTextStyles.productItemTotal.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (showAmountDue) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Amount Due:',
                    style: AppTextStyles.helperText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs. ${formatCashAmount(amountDue)}',
                    style: AppTextStyles.productItemTotal.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionHandleColor: AppColors.pepsiBlueLight,
            selectionColor: AppColors.textSecondary,
            cursorColor: AppColors.pepsiBlueLight,
          ),
        ),
        child: TextField(
          controller: _amountController,
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
            fillColor: Colors.white,
            hintText: "Amount Received",
            hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
            prefixIcon: const Icon(Icons.payments_outlined, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.pepsiBlue,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (value) {
            final amount = int.tryParse(value);
            if (amount != null && amount > amountDue) {
              _amountController.text = '0';
              _amountController.selection = TextSelection.fromPosition(
                TextPosition(offset: _amountController.text.length),
              );
            }
            setDialogState(() {});
          },
        ),
      ),
      if (hasEnteredAmount) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: displayRemainingAmount == 0
                ? Colors.green[50]
                : AppColors.pepsiBlueLight.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: displayRemainingAmount == 0
                  ? Colors.green[300]!
                  : AppColors.pepsiBlueLight.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                displayRemainingAmount == 0
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: displayRemainingAmount == 0
                    ? Colors.green[600]
                    : AppColors.pepsiBlueLight,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                displayRemainingAmount == 0 ? 'Fully Paid' : 'Balance:',
                style: AppTextStyles.helperText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: displayRemainingAmount == 0
                      ? Colors.green[700]
                      : AppColors.pepsiBlue,
                ),
              ),
              if (displayRemainingAmount > 0) ...[
                const Spacer(),
                Text(
                  'Rs. ${formatCashAmount(displayRemainingAmount)}',
                  style: AppTextStyles.productItemTotal.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pepsiBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildEditCratesSection(
    StateSetter setDialogState,
    int totalCrates,
    int cratesDue,
    int displayRemainingCrates,
    bool hasEnteredCrates,
  ) {
    final showCratesDue = totalCrates != cratesDue;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.gray300, width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Total Crates:',
                  style: AppTextStyles.helperText.copyWith(
                    fontSize: 13,
                    color: AppColors.gray500,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalCrates',
                  style: AppTextStyles.productItemTotal.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (showCratesDue) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                    color: AppColors.pepsiBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Due:',
                    style: AppTextStyles.helperText.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$cratesDue',
                    style: AppTextStyles.productItemTotal.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pepsiBlue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionHandleColor: AppColors.pepsiBlueLight,
            selectionColor: AppColors.textSecondary,
            cursorColor: AppColors.pepsiBlueLight,
          ),
        ),
        child: TextField(
          controller: _cratesController,
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
            fillColor: Colors.white,
            hintText: "Crates Received",
            hintStyle: AppTextStyles.inputHint.copyWith(fontSize: 13),
            prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray300, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.pepsiBlue,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (value) {
            final crates = int.tryParse(value);
            if (crates != null && crates > cratesDue) {
              _cratesController.text = '0';
              _cratesController.selection = TextSelection.fromPosition(
                TextPosition(offset: _cratesController.text.length),
              );
            }
            setDialogState(() {});
          },
        ),
      ),
      if (hasEnteredCrates) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: displayRemainingCrates == 0
                ? Colors.green[50]
                : AppColors.pepsiBlueLight.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: displayRemainingCrates == 0
                  ? Colors.green[300]!
                  : AppColors.pepsiBlueLight.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                displayRemainingCrates == 0
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: displayRemainingCrates == 0
                    ? Colors.green[600]
                    : AppColors.pepsiBlueLight,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                displayRemainingCrates == 0 ? 'All Returned' : 'Balance:',
                style: AppTextStyles.helperText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: displayRemainingCrates == 0
                      ? Colors.green[700]
                      : AppColors.pepsiBlue,
                ),
              ),
              if (displayRemainingCrates > 0) ...[
                const Spacer(),
                Text(
                  '$displayRemainingCrates',
                  style: AppTextStyles.productItemTotal.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pepsiBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _buildEditDialogActions(
    int index,
    bool hasEditableFields,
    List<CreditHistory> billHistory,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: AppColors.gray300,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Cancel',
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
                height: 48,
                child: ElevatedButton(
                  onPressed: hasEditableFields
                      ? () {
                          final amountReceived = int.tryParse(
                            _amountController.text,
                          );
                          final cratesReceived = int.tryParse(
                            _cratesController.text,
                          );

                          if ((amountReceived != null && amountReceived > 0) ||
                              (cratesReceived != null && cratesReceived > 0)) {
                            Navigator.pop(context);
                            _updateBillRecord(
                              index,
                              amountReceived,
                              cratesReceived,
                              billHistory,
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.pepsiBlueLight,
                    foregroundColor: AppColors.pepsiWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Update',
                    style: AppTextStyles.smallButton.copyWith(
                      color: AppColors.pepsiWhite,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: (hasEditableFields && _isPrinterConnected)
                ? () {
                    final amountReceived = int.tryParse(_amountController.text);
                    final cratesReceived = int.tryParse(_cratesController.text);

                    if ((amountReceived != null && amountReceived > 0) ||
                        (cratesReceived != null && cratesReceived > 0)) {
                      Navigator.pop(context);
                      _updateBillRecordAndPrint(
                        index,
                        amountReceived,
                        cratesReceived,
                        billHistory,
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: (hasEditableFields && _isPrinterConnected)
                  ? AppColors.pepsiBlueLight
                  : AppColors.gray300,
              foregroundColor: (hasEditableFields && _isPrinterConnected)
                  ? AppColors.pepsiWhite
                  : AppColors.gray500,
              disabledBackgroundColor: AppColors.gray300,
              disabledForegroundColor: AppColors.gray500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            icon: Icon(
              Icons.receipt_long,
              size: 20,
              color: (hasEditableFields && _isPrinterConnected)
                  ? AppColors.pepsiWhite
                  : AppColors.gray500,
            ),
            label: Text(
              _isPrinterConnected
                  ? 'Update & Print Receipt'
                  : 'Printer Not Connected',
              style: AppTextStyles.smallButton.copyWith(
                color: (hasEditableFields && _isPrinterConnected)
                    ? AppColors.pepsiWhite
                    : AppColors.gray500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
