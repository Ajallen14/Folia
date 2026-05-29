import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';

enum ExpenseFilter { today, thisMonth, lastMonth, allTime }

class DashboardState {
  final List<Map<String, dynamic>> allReceipts;
  final List<Map<String, dynamic>> filteredReceipts;
  final double totalSpent;
  final Map<String, double> categoryTotals;
  final bool isLoading;
  final ExpenseFilter currentFilter;

  DashboardState({
    this.allReceipts = const [],
    this.filteredReceipts = const [],
    this.totalSpent = 0.0,
    this.categoryTotals = const {},
    this.isLoading = true,
    this.currentFilter = ExpenseFilter.thisMonth,
  });
}

class ReceiptNotifier extends StateNotifier<DashboardState> {
  ReceiptNotifier() : super(DashboardState()) {
    refreshData();
  }

  Future<void> refreshData() async {
    state = DashboardState(
      isLoading: true,
      allReceipts: state.allReceipts,
      filteredReceipts: state.filteredReceipts,
      currentFilter: state.currentFilter,
    );

    final rawReceipts = await DatabaseHelper.instance.getAllReceipts();
    _applyFilter(rawReceipts, state.currentFilter);
  }

  void setFilter(ExpenseFilter newFilter) {
    _applyFilter(state.allReceipts, newFilter);
  }

  void _applyFilter(
    List<Map<String, dynamic>> rawReceipts,
    ExpenseFilter filter,
  ) {
    double total = 0.0;
    Map<String, double> catTotals = {};
    List<Map<String, dynamic>> filteredList = [];

    final now = DateTime.now();
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);

    for (var receipt in rawReceipts) {
      final date = DateTime.parse(receipt['purchase_date']);
      final amount = receipt['total_amount'] as double;
      final category = receipt['category_name'] ?? 'Other';

      bool include = false;

      if (filter == ExpenseFilter.allTime) {
        include = true;
      } else if (filter == ExpenseFilter.thisMonth) {
        if (date.month == now.month && date.year == now.year) include = true;
      } else if (filter == ExpenseFilter.lastMonth) {
        if (date.month == lastMonthDate.month &&
            date.year == lastMonthDate.year) {
          include = true;
        }
      } else if (filter == ExpenseFilter.today) {
        if (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day) {
          include = true;
        }
      }

      if (include) {
        filteredList.add(receipt);
        total += amount;

        if (catTotals.containsKey(category)) {
          catTotals[category] = catTotals[category]! + amount;
        } else {
          catTotals[category] = amount;
        }
      }
    }

    state = DashboardState(
      allReceipts: rawReceipts,
      filteredReceipts: filteredList,
      totalSpent: total,
      categoryTotals: catTotals,
      isLoading: false,
      currentFilter: filter,
    );
  }

  Future<void> deleteReceipt(String receiptId) async {
    await DatabaseHelper.instance.deleteReceipt(receiptId);
    await refreshData();
  }
}

final dashboardProvider =
    StateNotifierProvider<ReceiptNotifier, DashboardState>((ref) {
      return ReceiptNotifier();
    });
