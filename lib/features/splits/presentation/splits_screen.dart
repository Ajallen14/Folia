import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import 'split_detail_screen.dart';
import 'balances_screen.dart';
import '../../../core/widgets/glass_container.dart';

class SplitsScreen extends StatefulWidget {
  const SplitsScreen({super.key});

  @override
  State<SplitsScreen> createState() => _SplitsScreenState();
}

class _SplitsScreenState extends State<SplitsScreen> {
  Future<void> _showNameDialog(
    BuildContext context,
    Map<String, dynamic> receipt, {
    List<String>? initialPeople,
  }) async {
    List<String> people = initialPeople != null
        ? List.from(initialPeople)
        : ['Me'];
    final textController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                  const Text(
                    'Who is splitting this?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: people
                        .map(
                          (p) => Chip(
                            label: Text(
                              p,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: p == 'Me'
                                ? const Color(0xFFE0F7FA)
                                : const Color(0xFFE1BEE7),
                            deleteIcon: const Icon(
                              Icons.cancel,
                              color: Colors.black54,
                              size: 18,
                            ),
                            onDeleted: p == 'Me'
                                ? null
                                : () => setModalState(() => people.remove(p)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter name & tap +',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFFF8BBD0),
                          size: 28,
                        ),
                        onPressed: () {
                          if (textController.text.trim().isNotEmpty) {
                            setModalState(() {
                              people.add(textController.text.trim());
                              textController.clear();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SplitDetailScreen(
                              receipt: receipt,
                              friends: people,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE1BEE7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Start Splitting',
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 80,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Split Bills',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BalancesScreen()),
                ),
                child: const GlassContainer(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.people_alt_outlined, color: Colors.white),
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: Color(0xFFF8BBD0),
            labelColor: Color(0xFFF8BBD0),
            unselectedLabelColor: Colors.white54,
            dividerColor: Colors.white12,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Ready to Split'),
              Tab(text: 'Splitted Bills'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [_buildUnsplitTab(), _buildSplittedTab()],
        ),
      ),
    );
  }

  Widget _buildUnsplitTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getUnsplitReceipts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFF8BBD0)),
          );
        }
        final receipts = snapshot.data ?? [];

        if (receipts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'No new bills to split! Scan a detailed receipt to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: receipts.length,
          itemBuilder: (context, index) {
            final receipt = receipts[index];
            final rawDate = DateTime.parse(receipt['purchase_date']);
            final formattedDate = DateFormat('dd MMM yyyy').format(rawDate);
            final formattedAmount = NumberFormat.currency(
              symbol: '₹',
              decimalDigits: 2,
            ).format(receipt['total_amount']);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSplitCard(
                merchantName: receipt['merchant_name'],
                date: formattedDate,
                totalAmount: formattedAmount,
                buttonText: 'Split It',
                buttonColor: const Color(0xFFF8BBD0),
                onTap: () => _showNameDialog(context, receipt),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSplittedTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getSplitHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE0F7FA)),
          );
        }
        final receipts = snapshot.data ?? [];

        if (receipts.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'You haven\'t split any bills yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          itemCount: receipts.length,
          itemBuilder: (context, index) {
            final receipt = receipts[index];
            final rawDate = DateTime.parse(receipt['purchase_date']);
            final formattedDate = DateFormat('dd MMM yyyy').format(rawDate);
            final formattedAmount = NumberFormat.currency(
              symbol: '₹',
              decimalDigits: 2,
            ).format(receipt['total_amount']);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSplitCard(
                merchantName: receipt['merchant_name'],
                date: formattedDate,
                totalAmount: formattedAmount,
                buttonText: 'Edit Split',
                buttonColor: const Color(0xFFE0F7FA),
                onTap: () async {
                  final existingSplits = await DatabaseHelper.instance
                      .getSavedSplitsForReceipt(receipt['id'].toString());
                  Set<String> uniqueNames = {'Me'};
                  for (var split in existingSplits) {
                    if (split['user_name'] != null) {
                      uniqueNames.add(split['user_name']);
                    }
                  }
                  if (context.mounted) {
                    _showNameDialog(
                      context,
                      receipt,
                      initialPeople: uniqueNames.toList(),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSplitCard({
    required String merchantName,
    required String date,
    required String totalAmount,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7FA).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long, color: Color(0xFFE0F7FA)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchantName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  totalAmount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: buttonColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
}
