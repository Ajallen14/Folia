import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import 'widgets/budget_section.dart';
import 'widgets/receipt_list_item.dart';
import '../../scanner/presentation/receipt_preview_screen.dart';
import '../../../../core/database/database_helper.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);

    if (dashboardState.isLoading && dashboardState.allReceipts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE0F7FA)),
      );
    }

    String listTitle = 'Recent Receipts';
    if (dashboardState.currentFilter == ExpenseFilter.today) {
      listTitle = 'Receipts Today';
    }
    if (dashboardState.currentFilter == ExpenseFilter.lastMonth) {
      listTitle = 'Last Month\'s Receipts';
    }
    if (dashboardState.currentFilter == ExpenseFilter.allTime) {
      listTitle = 'All Receipts';
    }

    String emptyText = '';
    switch (dashboardState.currentFilter) {
      case ExpenseFilter.today:
        emptyText = 'No expenses logged today. Tap the scanner!';
        break;
      case ExpenseFilter.thisMonth:
        emptyText = 'No receipts this month. Tap the scanner!';
        break;
      case ExpenseFilter.lastMonth:
        emptyText = 'No receipts from last month.';
        break;
      case ExpenseFilter.allTime:
        emptyText = 'No receipts found. Tap the scanner!';
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFE0F7FA),
          backgroundColor: const Color(0xFF2C2C2E),
          onRefresh: () async {
            ref.read(dashboardProvider.notifier).refreshData();
            setState(() {});
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 30),

                _buildSpendingSummary(dashboardState, ref),
                const SizedBox(height: 30),

                _buildChartSection(dashboardState),
                const SizedBox(height: 40),

                BudgetSection(categoryTotals: dashboardState.categoryTotals),
                const SizedBox(height: 40),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    listTitle,
                    key: ValueKey(dashboardState.currentFilter),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: dashboardState.filteredReceipts.isEmpty
                      ? Center(
                          key: const ValueKey('empty_state'),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text(
                              emptyText,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                        )
                      : ListView.builder(
                          key: ValueKey('list_${dashboardState.currentFilter}'),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dashboardState.filteredReceipts.length,
                          itemBuilder: (context, index) {
                            final receipt =
                                dashboardState.filteredReceipts[index];
                            final rawDate = DateTime.parse(
                              receipt['purchase_date'],
                            );
                            final formattedDate = DateFormat(
                              'dd-MM-yyyy',
                            ).format(rawDate);
                            final formattedAmount = NumberFormat.currency(
                              symbol: '₹',
                              decimalDigits: 2,
                            ).format(receipt['total_amount']);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Dismissible(
                                key: Key(receipt['id'].toString()),
                                direction: DismissDirection.startToEnd,
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.delete_sweep_rounded,
                                    color: Colors.redAccent,
                                    size: 30,
                                  ),
                                ),
                                onDismissed: (direction) {
                                  ref
                                      .read(dashboardProvider.notifier)
                                      .deleteReceipt(receipt['id']);

                                  // Clear any existing snackbars so they don't queue up
                                  ScaffoldMessenger.of(
                                    context,
                                  ).clearSnackBars();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '${receipt['merchant_name']} deleted',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.redAccent
                                          .withOpacity(0.9),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      margin: const EdgeInsets.only(
                                        bottom: 30,
                                        left: 20,
                                        right: 20,
                                      ),
                                      elevation: 10,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },

                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () async {
                                    try {
                                      String receiptId =
                                          receipt['id']?.toString() ?? '';

                                      if (receiptId.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Error: Could not find Receipt ID in database',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      // Fetch the line items using the String UUID
                                      final items = await DatabaseHelper
                                          .instance
                                          .getReceiptItems(receiptId);

                                      // Combine the receipt data with its items
                                      final fullData =
                                          Map<String, dynamic>.from(receipt);
                                      fullData['items'] = items;

                                      if (context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ReceiptPreviewScreen(
                                                  initialData: fullData,
                                                  imagePath:
                                                      receipt['image_path'] ??
                                                      '',
                                                  isEditing: true,
                                                ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error opening receipt: $e',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                            duration: const Duration(
                                              seconds: 4,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: ReceiptListItem(
                                    merchantName: receipt['merchant_name'],
                                    category:
                                        receipt['category_name'] ?? 'Other',
                                    date: formattedDate,
                                    totalAmount: formattedAmount,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSpendingSummary(DashboardState state, WidgetRef ref) {
    String filterText = '';
    switch (state.currentFilter) {
      case ExpenseFilter.today:
        filterText = 'Today';
        break;
      case ExpenseFilter.thisMonth:
        filterText = 'This Month';
        break;
      case ExpenseFilter.lastMonth:
        filterText = 'Last Month';
        break;
      case ExpenseFilter.allTime:
        filterText = 'All Time';
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Theme(
          data: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: PopupMenuButton<ExpenseFilter>(
            initialValue: state.currentFilter,
            color: const Color(0xFF262628),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            offset: const Offset(0, 45),
            onSelected: (ExpenseFilter filter) =>
                ref.read(dashboardProvider.notifier).setFilter(filter),
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<ExpenseFilter>>[
                  const PopupMenuItem<ExpenseFilter>(
                    value: ExpenseFilter.thisMonth,
                    child: Text(
                      'This Month',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem<ExpenseFilter>(
                    value: ExpenseFilter.lastMonth,
                    child: Text(
                      'Last Month',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const PopupMenuItem<ExpenseFilter>(
                    value: ExpenseFilter.today,
                    child: Text('Today', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuDivider(height: 1),
                  const PopupMenuItem<ExpenseFilter>(
                    value: ExpenseFilter.allTime,
                    child: Text(
                      'All Time',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
            child: _buildGlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text(filterText, style: const TextStyle(color: Colors.white)),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          children: [
            const Text(
              'Total Spent  ',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: state.totalSpent),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                final formattedTotal = NumberFormat.currency(
                  symbol: '₹',
                  decimalDigits: 2,
                ).format(value);
                return Text(
                  formattedTotal,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection(DashboardState state) {
    String subtitleText = '';
    switch (state.currentFilter) {
      case ExpenseFilter.today:
        subtitleText = 'Total today';
        break;
      case ExpenseFilter.thisMonth:
        subtitleText = 'Total this month';
        break;
      case ExpenseFilter.lastMonth:
        subtitleText = 'Total last month';
        break;
      case ExpenseFilter.allTime:
        subtitleText = 'Total all time';
        break;
    }

    List<PieChartSectionData> sections = [];
    if (state.categoryTotals.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: Colors.white12,
          value: 1,
          radius: 15,
          showTitle: false,
        ),
      );
    } else {
      state.categoryTotals.forEach((category, amount) {
        Color sliceColor = const Color(0xFFCFD8DC);
        switch (category) {
          case 'Groceries':
            sliceColor = const Color(0xFFE1BEE7);
            break;
          case 'Food & Dining':
            sliceColor = const Color(0xFFB2DFDB);
            break;
          case 'Travel & Transport':
            sliceColor = const Color(0xFFFFCCBC);
            break;
          case 'Shopping & Retail':
            sliceColor = const Color(0xFFF8BBD0);
            break;
          case 'Electronics':
            sliceColor = const Color(0xFFFFF9C4);
            break;
          case 'Health & Pharmacy':
            sliceColor = const Color(0xFFC8E6C9);
            break;
          case 'Home & Maintenance':
            sliceColor = const Color(0xFFD7CCC8);
            break;
          case 'Entertainment':
            sliceColor = const Color(0xFFBBDEFB);
            break;
          case 'Utility Bills':
            sliceColor = const Color(0xFFB3E5FC);
            break;
        }
        sections.add(
          PieChartSectionData(
            color: sliceColor,
            value: amount,
            radius: 15,
            showTitle: false,
          ),
        );
      });
    }

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 75,
              startDegreeOffset: -90,
              sections: sections,
            ),
            swapAnimationDuration: const Duration(milliseconds: 600),
            swapAnimationCurve: Curves.easeInOutCubic,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: state.totalSpent),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final formattedTotal = NumberFormat.currency(
                    symbol: '₹',
                    decimalDigits: 0,
                  ).format(value);
                  return Text(
                    formattedTotal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  subtitleText,
                  key: ValueKey(subtitleText),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    required EdgeInsets padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
