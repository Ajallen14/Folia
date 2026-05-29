import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../core/database/database_helper.dart';
import '../../dashboard/providers/receipt_provider.dart';

class ReceiptPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialData;
  final String imagePath;
  final bool isEditing;

  const ReceiptPreviewScreen({
    super.key,
    required this.initialData,
    required this.imagePath,
    this.isEditing = false,
  });

  @override
  ConsumerState<ReceiptPreviewScreen> createState() =>
      _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends ConsumerState<ReceiptPreviewScreen> {
  late TextEditingController _merchantController;
  late TextEditingController _dateController;
  late TextEditingController _totalController;

  final List<Map<String, dynamic>> _editableItems = [];
  bool _isSaving = false;

  String _selectedCategory = 'Other';

  final List<String> _categories = [
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
  ];

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(
      text: widget.initialData['merchant_name']?.toString(),
    );
    _dateController = TextEditingController(
      text:
          widget.initialData['date'] ??
          widget.initialData['purchase_date']?.toString(),
    );
    _totalController = TextEditingController(
      text: widget.initialData['total_amount']?.toString(),
    );

    if (widget.initialData['receipt_category'] != null &&
        _categories.contains(widget.initialData['receipt_category'])) {
      _selectedCategory = widget.initialData['receipt_category'];
    } else if (widget.initialData['category_name'] != null &&
        _categories.contains(widget.initialData['category_name'])) {
      _selectedCategory = widget.initialData['category_name'];
    }

    // Load existing items if they exist
    if (widget.initialData['items'] != null) {
      for (var item in widget.initialData['items']) {
        _editableItems.add({
          'nameController': TextEditingController(
            text: (item['item_name'] ?? item['name'])?.toString() ?? '',
          ),
          'qtyController': TextEditingController(
            text: (item['quantity'] ?? 1).toString(),
          ),
          'priceController': TextEditingController(
            text: (item['price'] ?? 0.0).toString(),
          ),
        });
      }
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _dateController.dispose();
    _totalController.dispose();
    for (var item in _editableItems) {
      item['nameController'].dispose();
      item['qtyController'].dispose();
      item['priceController'].dispose();
    }
    super.dispose();
  }

  void _addNewItem() {
    setState(() {
      _editableItems.add({
        'nameController': TextEditingController(),
        'qtyController': TextEditingController(text: '1'),
        'priceController': TextEditingController(),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      final item = _editableItems.removeAt(index);
      item['nameController'].dispose();
      item['qtyController'].dispose();
      item['priceController'].dispose();
    });
  }

  Map<String, dynamic> _getCategoryStyling(String category) {
    switch (category) {
      case 'Groceries':
        return {
          'icon': Icons.local_grocery_store_outlined,
          'color': const Color(0xFFE1BEE7),
        };
      case 'Food & Dining':
        return {
          'icon': Icons.restaurant_outlined,
          'color': const Color(0xFFB2DFDB),
        };
      case 'Travel & Transport':
        return {
          'icon': Icons.directions_car_outlined,
          'color': const Color(0xFFFFCCBC),
        };
      case 'Shopping & Retail':
        return {
          'icon': Icons.shopping_bag_outlined,
          'color': const Color(0xFFF8BBD0),
        };
      case 'Electronics':
        return {
          'icon': Icons.devices_other_outlined,
          'color': const Color(0xFFFFF9C4),
        };
      case 'Health & Pharmacy':
        return {
          'icon': Icons.medical_services_outlined,
          'color': const Color(0xFFC8E6C9),
        };
      case 'Home & Maintenance':
        return {
          'icon': Icons.home_repair_service_outlined,
          'color': const Color(0xFFD7CCC8),
        };
      case 'Entertainment':
        return {
          'icon': Icons.sports_esports_outlined,
          'color': const Color(0xFFBBDEFB),
        };
      case 'Utility Bills':
        return {'icon': Icons.bolt_outlined, 'color': const Color(0xFFB3E5FC)};
      case 'Other':
      default:
        return {
          'icon': Icons.receipt_long_outlined,
          'color': const Color(0xFFCFD8DC),
        };
    }
  }

  Future<void> _showCategoryPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Select Category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final style = _getCategoryStyling(category);
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: style['color'].withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          style['icon'],
                          color: style['color'],
                          size: 18,
                        ),
                      ),
                      title: Text(
                        category,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: _selectedCategory == category
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.teal,
                              size: 20,
                            )
                          : const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white24,
                              size: 16,
                            ),
                      onTap: () => Navigator.pop(context, category),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCategory = selected;
      });
    }
  }

  // --- SAVE LOGIC ---
  Future<void> _saveCorrectedData() async {
    setState(() => _isSaving = true);

    List<Map<String, dynamic>> finalItems = _editableItems.map((item) {
      return {
        'item_name': item['nameController'].text.trim(),
        'quantity': int.tryParse(item['qtyController'].text) ?? 1,
        'price': double.tryParse(item['priceController'].text) ?? 0.0,
      };
    }).toList();

    Map<String, dynamic> finalData = {
      'merchant_name': _merchantController.text.trim(),
      'date': _dateController.text.trim(),
      'total_amount': double.tryParse(_totalController.text) ?? 0.0,
      'receipt_category': _selectedCategory,
      'items': finalItems,
    };

    try {
      if (widget.isEditing && widget.initialData.containsKey('id')) {
        await DatabaseHelper.instance.updateReceipt(
          widget.initialData['id'].toString(),
          finalData,
        );
      } else {
        await DatabaseHelper.instance.saveReceiptFromGemini(
          finalData,
          widget.imagePath,
        );
      }

      await ref.read(dashboardProvider.notifier).refreshData();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black87,
          builder: (context) {
            return Center(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Center(
                  child: Lottie.asset(
                    'assets/animations/Save_animation.json',
                    repeat: false,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        );

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCategoryStyle = _getCategoryStyling(_selectedCategory);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditing ? 'Edit Receipt' : 'Review Receipt',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFFE0F7FA),
            ),
            onPressed: _addNewItem,
            tooltip: 'Add missing item',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGlassContainer(
                      child: Column(
                        children: [
                          _buildTextField(
                            _merchantController,
                            'Merchant Name',
                            Icons.storefront_outlined,
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  _dateController,
                                  'YYYY-MM-DD',
                                  Icons.calendar_today_outlined,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.white12,
                              ),
                              Expanded(
                                child: _buildTextField(
                                  _totalController,
                                  'Total (₹)',
                                  Icons.currency_rupee_outlined,
                                  isNumber: true,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 1),

                          InkWell(
                            onTap: _showCategoryPicker,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: currentCategoryStyle['color']
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      currentCategoryStyle['icon'],
                                      color: currentCategoryStyle['color'],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      _selectedCategory,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white24,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    const Text(
                      'Line Items',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ..._editableItems.asMap().entries.map((entry) {
                      int index = entry.key;
                      var item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildGlassContainer(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      item['nameController'],
                                      'Item Name',
                                      Icons.fastfood_outlined,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.redAccent,
                                      size: 22,
                                    ),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 1),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: _buildTextField(
                                      item['qtyController'],
                                      'Qty',
                                      Icons.numbers_rounded,
                                      isNumber: true,
                                      isCenter: true,
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 50,
                                    color: Colors.white12,
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTextField(
                                      item['priceController'],
                                      'Total Price',
                                      Icons.currency_rupee_outlined,
                                      isNumber: true,
                                    ),
                                  ),
                                ],
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

            Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: _isSaving ? null : _saveCorrectedData,
                child: Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0F7FA), Color(0xFFF8BBD0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF8BBD0).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black87,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            widget.isEditing
                                ? 'Save Changes'
                                : 'Confirm & Save',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
    bool isCenter = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textAlign: isCenter ? TextAlign.center : TextAlign.start,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        prefixIcon: isCenter
            ? null
            : Icon(icon, color: Colors.white54, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isCenter ? 15 : 12,
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
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
          child: child,
        ),
      ),
    );
  }
}
