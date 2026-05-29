import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExportReceiptWidget extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final List<String> friends;
  final List<Map<String, dynamic>> lineItems;
  final Map<String, List<String>> itemAssignments;
  final Map<String, Map<String, int>> itemQtyAllocations;

  const ExportReceiptWidget({
    super.key,
    required this.receipt,
    required this.friends,
    required this.lineItems,
    required this.itemAssignments,
    required this.itemQtyAllocations,
  });

  double _calculateOwedForItem(Map<String, dynamic> item, String person) {
    final itemId = item['id'];
    final assignedTo = itemAssignments[itemId]!;

    if (!assignedTo.contains(person)) return 0.0;

    final int totalQty = (item['quantity'] as num?)?.toInt() ?? 1;
    final double totalPrice = (item['price'] as num).toDouble();

    if (totalQty <= 1) return totalPrice / assignedTo.length;

    final allocations = itemQtyAllocations[itemId]!;
    int sumAllocated = allocations.values.fold(0, (sum, val) => sum + val);

    if (sumAllocated == 0) return totalPrice / assignedTo.length;

    final double unitPrice = totalPrice / totalQty;
    final int myAllocated = allocations[person] ?? 0;

    double owed = (myAllocated * unitPrice).toDouble();

    final int remainderQty = totalQty - sumAllocated;
    if (remainderQty > 0) {
      owed += (remainderQty * unitPrice) / assignedTo.length;
    }

    return owed;
  }

  double _calculateTotalFor(String person) {
    double total = 0.0;
    for (var item in lineItems) {
      total += _calculateOwedForItem(item, person);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1C),
          border: Border.all(
            color: const Color(0xFFF8BBD0).withOpacity(0.4),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'FOLIA',
                style: TextStyle(
                  color: Color(0xFFE0F7FA),
                  fontSize: 16,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              receipt['merchant_name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Bill Split Summary',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const Divider(color: Colors.white24, height: 40, thickness: 1),

            ...friends.map((friend) {
              double total = _calculateTotalFor(friend);
              if (total <= 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          friend.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFFF8BBD0),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          NumberFormat.currency(
                            symbol: '₹',
                            decimalDigits: 2,
                          ).format(total),
                          style: const TextStyle(
                            color: Color(0xFFF8BBD0),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ...lineItems.map((item) {
                      double owed = _calculateOwedForItem(item, friend);
                      if (owed <= 0) return const SizedBox.shrink();

                      final itemId = item['id'];
                      final totalQty = (item['quantity'] as num?)?.toInt() ?? 1;
                      final assignedTo = itemAssignments[itemId]!;
                      final allocations = itemQtyAllocations[itemId]!;
                      int myAllocated = allocations[friend] ?? 0;

                      String desc = item['item_name'];
                      if (totalQty > 1 && myAllocated > 0) {
                        desc = '${myAllocated}x $desc';
                      } else if (assignedTo.length > 1) {
                        desc = '$desc (Shared)';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                desc,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                symbol: '₹',
                                decimalDigits: 2,
                              ).format(owed),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

            const Divider(color: Colors.white24, height: 32, thickness: 1),
            const Center(
              child: Text(
                'Calculated with ❤️ by FOLIA',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
