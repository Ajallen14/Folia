import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_helper.dart';

class BudgetSection extends StatefulWidget {
  final Map<String, double> categoryTotals;

  const BudgetSection({super.key, required this.categoryTotals});

  @override
  State<BudgetSection> createState() => _BudgetSectionState();
}

class _BudgetSectionState extends State<BudgetSection> {
  Map<String, dynamic> _getCategoryStyling(String category) {
    switch (category) {
      case 'Groceries':
        return {'color': const Color(0xFFE1BEE7)};
      case 'Food & Dining':
        return {'color': const Color(0xFFB2DFDB)};
      case 'Travel & Transport':
        return {'color': const Color(0xFFFFCCBC)};
      case 'Shopping & Retail':
        return {'color': const Color(0xFFF8BBD0)};
      case 'Electronics':
        return {'color': const Color(0xFFFFF9C4)};
      case 'Health & Pharmacy':
        return {'color': const Color(0xFFC8E6C9)};
      case 'Home & Maintenance':
        return {'color': const Color(0xFFD7CCC8)};
      case 'Entertainment':
        return {'color': const Color(0xFFBBDEFB)};
      case 'Utility Bills':
        return {'color': const Color(0xFFB3E5FC)};
      case 'Other':
      default:
        return {'color': const Color(0xFFCFD8DC)};
    }
  }

  void _showAddBudgetDialog({String? initialCategory, double? initialLimit}) {
    String selectedCategory = initialCategory ?? 'Groceries';
    final limitController = TextEditingController(
      text: initialLimit != null ? initialLimit.toInt().toString() : '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    initialCategory == null
                        ? 'Set Monthly Budget'
                        : 'Edit Budget',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategory,
                        dropdownColor: const Color(0xFF2C2C2E),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white54,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        onChanged: initialCategory != null
                            ? null
                            : (val) {
                                if (val != null)
                                  setModalState(() => selectedCategory = val);
                              },
                        items:
                            [
                                  'Groceries',
                                  'Food & Dining',
                                  'Travel & Transport',
                                  'Shopping & Retail',
                                  'Electronics',
                                  'Health & Pharmacy',
                                  'Home & Maintenance',
                                  'Entertainment',
                                  'Utility Bills',
                                  'Other',
                                ]
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter monthly limit (₹)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () async {
                        final limit =
                            double.tryParse(limitController.text) ?? 0.0;
                        if (limit > 0) {
                          await DatabaseHelper.instance.setBudget(
                            selectedCategory,
                            limit,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            setState(() {});
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0F7FA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Budget',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteBudget(String category) async {
    await DatabaseHelper.instance.deleteBudget(category);
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getBudgets(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildGlassContainer(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7FA).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.track_changes,
                    color: Color(0xFFE0F7FA),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set a Budget',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Track your monthly limits',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: Color(0xFFE0F7FA),
                    size: 32,
                  ),
                  onPressed: () => _showAddBudgetDialog(),
                ),
              ],
            ),
          );
        }

        final budgets = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Budgets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFFE0F7FA),
                  ),
                  onPressed: () => _showAddBudgetDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...budgets.map((budget) {
              final category = budget['category_name'];
              final limit = (budget['monthly_limit'] as num).toDouble();
              final spent = widget.categoryTotals[category] ?? 0.0;
              final percent = limit > 0 ? (spent / limit) : 0.0;
              final clampedPercent = percent.clamp(0.0, 1.0);

              // DYNAMIC COLOR LOGIC
              Color dynamicColor;
              if (percent >= 1.0) {
                dynamicColor = Colors.redAccent;
              } else if (percent >= 0.75) {
                dynamicColor = Colors.orangeAccent;
              } else {
                dynamicColor = _getCategoryStyling(category)['color'];
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(spent)} / ${NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(limit)}',
                          style: TextStyle(
                            color: percent >= 1.0
                                ? Colors.redAccent
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white54,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          color: const Color(0xFF2C2C2E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showAddBudgetDialog(
                                initialCategory: category,
                                initialLimit: limit,
                              );
                            } else if (value == 'delete') {
                              _deleteBudget(category);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text(
                                'Edit Limit',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete Budget',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 8,
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              height: 8,
                              width: constraints.maxWidth * clampedPercent,
                              decoration: BoxDecoration(
                                color: dynamicColor,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: dynamicColor.withOpacity(0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
