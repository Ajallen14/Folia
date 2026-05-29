import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database_helper.dart';

class BalancesScreen extends StatefulWidget {
  const BalancesScreen({super.key});

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends State<BalancesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _groupedBalances = [];
  List<Map<String, dynamic>> _history = [];
  double _grandTotalOwed = 0.0;

  // State Variables for Sharing
  final GlobalKey _historyBoundaryKey = GlobalKey();
  Map<String, dynamic>? _receiptToShare;
  List<Map<String, dynamic>> _splitsToShare = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final rawDetails = await DatabaseHelper.instance.getDetailedBalances();
    final history = await DatabaseHelper.instance.getSplitHistory();

    Map<String, Map<String, dynamic>> grouped = {};
    double grandTotal = 0.0;

    for (var row in rawDetails) {
      String rawName = row['user_name'];
      String cleanName = rawName
          .trim()
          .split(' ')
          .map(
            (w) => w.isNotEmpty
                ? w[0].toUpperCase() + w.substring(1).toLowerCase()
                : '',
          )
          .join(' ');

      if (!grouped.containsKey(cleanName)) {
        grouped[cleanName] = {
          'totalOwed': 0.0,
          'bills': <Map<String, dynamic>>[],
        };
      }

      double owed = (row['amount_owed_for_bill'] as num).toDouble();
      grouped[cleanName]!['totalOwed'] += owed;

      grouped[cleanName]!['bills'].add({
        'receipt_id': row['receipt_id'],
        'merchant_name': row['merchant_name'],
        'purchase_date': row['purchase_date'],
        'amount': owed,
      });

      grandTotal += owed;
    }

    final sortedKeys = grouped.keys.toList()..sort();
    final finalBalances = sortedKeys.map((k) {
      return {
        'name': k,
        'totalOwed': grouped[k]!['totalOwed'],
        'bills': grouped[k]!['bills'],
      };
    }).toList();

    setState(() {
      _groupedBalances = finalBalances;
      _history = history;
      _grandTotalOwed = grandTotal;
      _isLoading = false;
    });
  }

  Future<void> _markAsPaid(String friendName) async {
    await DatabaseHelper.instance.settleBalance(friendName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$friendName settled up!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
    _loadData();
  }

  Future<void> _markSpecificBillAsPaid(
    String friendName,
    String receiptId,
    String merchantName,
  ) async {
    await DatabaseHelper.instance.settleSpecificBill(friendName, receiptId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$friendName settled the $merchantName bill!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
    _loadData();
  }

  // SHARE HISTORY RECEIPT LOGIC
  Future<void> _shareHistoryReceipt(Map<String, dynamic> receipt) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating receipt...'),
          duration: Duration(seconds: 1),
        ),
      );

      final splits = await DatabaseHelper.instance.getSavedSplitsForReceipt(
        receipt['id'],
      );

      setState(() {
        _receiptToShare = receipt;
        _splitsToShare = splits;
      });

      await Future.delayed(const Duration(milliseconds: 150));

      RenderRepaintBoundary boundary =
          _historyBoundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File(
        '${directory.path}/folia_history.png',
      ).create();
      await imagePath.writeAsBytes(pngBytes);

      final merchant = receipt['merchant_name'];
      await Share.shareXFiles([
        XFile(imagePath.path),
      ], text: 'Here is the breakdown for $merchant');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _receiptToShare = null;
          _splitsToShare = [];
        });
      }
    }
  }

  Widget _buildHiddenHistoryExport() {
    if (_receiptToShare == null || _splitsToShare.isEmpty) {
      return const SizedBox.shrink();
    }

    Map<String, List<Map<String, dynamic>>> groupedSplits = {};
    Map<String, double> userTotals = {};

    for (var split in _splitsToShare) {
      String user = split['user_name'];
      if (!groupedSplits.containsKey(user)) {
        groupedSplits[user] = [];
        userTotals[user] = 0.0;
      }
      groupedSplits[user]!.add(split);
      userTotals[user] =
          userTotals[user]! + (split['owed_amount'] as num).toDouble();
    }

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
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/folia_logo.png',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FOLIA',
                    style: TextStyle(
                      color: Color(0xFFE0F7FA),
                      fontSize: 16,
                      letterSpacing: 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _receiptToShare!['merchant_name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Saved Bill Summary',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const Divider(color: Colors.white24, height: 40, thickness: 1),

            ...groupedSplits.keys.map((friend) {
              double total = userTotals[friend]!;
              final items = groupedSplits[friend]!;

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
                    ...items.map((item) {
                      double owed = (item['owed_amount'] as num).toDouble();
                      String desc = item['item_name'];
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
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Calculated with ❤️ by FOLIA',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Friends & Balances',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. HIDDEN BOUNDARY FOR TAKING SHARE PICTURE
          Positioned(
            top: -9999,
            left: -9999,
            child: RepaintBoundary(
              key: _historyBoundaryKey,
              child: _buildHiddenHistoryExport(),
            ),
          ),

          // 2. VISIBLE UI
          Positioned.fill(
            child: SafeArea(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE0F7FA),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFE0F7FA),
                      backgroundColor: const Color(0xFF2C2C2E),
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  const Text(
                                    'Total Owed to You',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    NumberFormat.currency(
                                      symbol: '₹',
                                      decimalDigits: 2,
                                    ).format(_grandTotalOwed),
                                    style: const TextStyle(
                                      color: Color(0xFFE0F7FA),
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),

                            const Text(
                              'Who Owes You',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_groupedBalances.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text(
                                    'You are all settled up!',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              )
                            else
                              ..._groupedBalances.map((b) {
                                final friendName = b['name'];
                                final amount = NumberFormat.currency(
                                  symbol: '₹',
                                  decimalDigits: 2,
                                ).format(b['totalOwed']);
                                final bills = b['bills'] as List;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildGlassContainer(
                                    padding: EdgeInsets.zero,
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent,
                                      ),
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                        leading: CircleAvatar(
                                          backgroundColor: const Color(
                                            0xFFF8BBD0,
                                          ).withOpacity(0.2),
                                          child: Text(
                                            friendName[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFFF8BBD0),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          friendName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Owes $amount',
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        iconColor: Colors.white54,
                                        collapsedIconColor: Colors.white54,
                                        children: [
                                          const Divider(
                                            color: Colors.white12,
                                            height: 1,
                                          ),
                                          Container(
                                            color: Colors.black12,
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Bills Breakdown',
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),

                                                // SPECIFIC CHECKMARKS
                                                ...bills.map((bill) {
                                                  final date =
                                                      DateFormat(
                                                        'dd MMM',
                                                      ).format(
                                                        DateTime.parse(
                                                          bill['purchase_date'],
                                                        ),
                                                      );
                                                  final billAmount =
                                                      NumberFormat.currency(
                                                        symbol: '₹',
                                                        decimalDigits: 2,
                                                      ).format(bill['amount']);
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            '${bill['merchant_name']} ($date)',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                ),
                                                          ),
                                                        ),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              billAmount,
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            GestureDetector(
                                                              onTap: () =>
                                                                  _markSpecificBillAsPaid(
                                                                    friendName,
                                                                    bill['receipt_id'],
                                                                    bill['merchant_name'],
                                                                  ),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      6,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      const Color(
                                                                        0xFFE0F7FA,
                                                                      ).withOpacity(
                                                                        0.15,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                                child: const Icon(
                                                                  Icons
                                                                      .check_rounded,
                                                                  color: Color(
                                                                    0xFFE0F7FA,
                                                                  ),
                                                                  size: 18,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                                const SizedBox(height: 16),

                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    onPressed: () =>
                                                        _markAsPaid(friendName),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                            0xFFE0F7FA,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Mark All as Paid',
                                                      style: TextStyle(
                                                        color: Colors.black87,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),

                            const SizedBox(height: 40),

                            const Text(
                              'Split History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_history.isEmpty)
                              const Center(
                                child: Text(
                                  'No bills split yet.',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            else
                              ..._history.map((receipt) {
                                final date = DateFormat('dd MMM yyyy').format(
                                  DateTime.parse(receipt['purchase_date']),
                                );
                                final amount = NumberFormat.currency(
                                  symbol: '₹',
                                  decimalDigits: 2,
                                ).format(receipt['total_amount']);

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      receipt['merchant_name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      date,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          amount,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: () =>
                                              _shareHistoryReceipt(receipt),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFE0F7FA,
                                              ).withOpacity(0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.share_rounded,
                                              color: Color(0xFFE0F7FA),
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
            ),
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
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
