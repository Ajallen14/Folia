import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/gradient_button.dart';

class SplitDetailScreen extends StatefulWidget {
  final Map<String, dynamic> receipt;
  final List<String> friends;

  const SplitDetailScreen({
    super.key,
    required this.receipt,
    required this.friends,
  });

  @override
  State<SplitDetailScreen> createState() => _SplitDetailScreenState();
}

class _SplitDetailScreenState extends State<SplitDetailScreen> {
  List<Map<String, dynamic>> _lineItems = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, List<String>> _itemAssignments = {};
  final Map<String, Map<String, int>> _itemQtyAllocations = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await DatabaseHelper.instance.getLineItems(widget.receipt['id']);
    setState(() {
      _lineItems = items;
      _isLoading = false;
      for (var item in items) {
        _itemAssignments[item['id']] = [];
        _itemQtyAllocations[item['id']] = {};
      }
    });
  }

  void _toggleAssignment(String itemId, String person) {
    setState(() {
      final assignedTo = _itemAssignments[itemId]!;
      if (assignedTo.contains(person)) {
        assignedTo.remove(person);
        _itemQtyAllocations[itemId]!.remove(person);
      } else {
        assignedTo.add(person);
        _itemQtyAllocations[itemId]![person] = 0;
      }
    });
  }

  void _adjustAllocation(String itemId, String person, int delta, int maxQty) {
    setState(() {
      final allocations = _itemQtyAllocations[itemId]!;
      int current = allocations[person] ?? 0;
      int sumAllocated = allocations.values.fold(0, (sum, val) => sum + val);

      if (delta > 0 && sumAllocated >= maxQty) return;
      if (delta < 0 && current <= 0) return;

      allocations[person] = current + delta;
    });
  }

  double _calculateOwedForItem(Map<String, dynamic> item, String person) {
    final itemId = item['id'];
    final assignedTo = _itemAssignments[itemId]!;
    final int totalQty = (item['quantity'] as num?)?.toInt() ?? 1;
    final double totalPrice = (item['price'] as num).toDouble();

    if (assignedTo.isEmpty) return totalPrice / widget.friends.length;
    if (!assignedTo.contains(person)) return 0.0;
    if (totalQty <= 1) return totalPrice / assignedTo.length;

    final allocations = _itemQtyAllocations[itemId]!;
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
    for (var item in _lineItems) {
      total += _calculateOwedForItem(item, person);
    }
    return total;
  }

  Future<void> _saveSplits() async {
    setState(() => _isSaving = true);
    List<Map<String, dynamic>> splitsToSave = [];

    for (var item in _lineItems) {
      final assignedTo = _itemAssignments[item['id']]!;
      final peopleToCharge = assignedTo.isEmpty ? widget.friends : assignedTo;

      for (var person in peopleToCharge) {
        final owed = _calculateOwedForItem(item, person);
        if (owed > 0) {
          splitsToSave.add({'line_item_id': item['id'], 'user_name': person, 'owed_amount': owed});
        }
      }
    }

    try {
      await DatabaseHelper.instance.saveSplits(widget.receipt['id'], splitsToSave);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Splits saved successfully!'), backgroundColor: Colors.teal));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving splits: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedTotal = NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(widget.receipt['total_amount']);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(widget.receipt['merchant_name'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(formattedTotal, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFFF8BBD0))))
            else if (_lineItems.isEmpty)
              const Expanded(child: Center(child: Text('No line items found.', style: TextStyle(color: Colors.white54))))
            else
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _lineItems.length,
                  itemBuilder: (context, index) {
                    final item = _lineItems[index];
                    final itemId = item['id'];
                    final price = NumberFormat.currency(symbol: '₹', decimalDigits: 2).format(item['price']);
                    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                    final assignedTo = _itemAssignments[itemId]!;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('${qty}x  ${item['item_name']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
                                Text(price, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),

                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: widget.friends.map((friend) {
                                  final isSelected = assignedTo.contains(friend);
                                  final allocatedQty = _itemQtyAllocations[itemId]?[friend] ?? 0;

                                  return GestureDetector(
                                    onTap: () => _toggleAssignment(itemId, friend),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFF8BBD0) : Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: isSelected ? const Color(0xFFF8BBD0) : Colors.white.withOpacity(0.1)),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(friend, style: TextStyle(color: isSelected ? Colors.black87 : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                                          if (isSelected && qty > 1) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _adjustAllocation(itemId, friend, -1, qty),
                                                    behavior: HitTestBehavior.opaque,
                                                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('-', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18))),
                                                  ),
                                                  SizedBox(width: 16, child: Text('$allocatedQty', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14))),
                                                  GestureDetector(
                                                    onTap: () => _adjustAllocation(itemId, friend, 1, qty),
                                                    behavior: HitTestBehavior.opaque,
                                                    child: const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Text('+', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18))),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: widget.friends.map((friend) {
                          final total = NumberFormat.currency(symbol: '₹', decimalDigits: 0).format(_calculateTotalFor(friend));
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              children: [
                                Text(friend, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(total, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    GradientButton(
                      text: 'Save Splits',
                      isLoading: _isSaving,
                      onPressed: _saveSplits,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}