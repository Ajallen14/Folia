import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../core/database/database_helper.dart';
import '../../dashboard/providers/receipt_provider.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/gradient_button.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? prefilledData;
  const ManualEntryScreen({super.key, this.prefilledData});
  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Other';
  bool _isSaving = false;

  final List<Map<String, dynamic>> _editableItems = [];
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
    if (widget.prefilledData != null) {
      _merchantController.text = widget.prefilledData!['merchant_name'] ?? '';
      final total = widget.prefilledData!['total_amount'];
      if (total != null && total > 0.0) {
        _amountController.text = total.toString();
      }

      final dateStr = widget.prefilledData!['date'];
      if (dateStr != null) {
          DateTime? parsedDate = DateTime.tryParse(
            dateStr.replaceAll('/', '-'),
          );
          if (parsedDate != null) _selectedDate = parsedDate;
      }

      final items =
          widget.prefilledData!['items'] as List<Map<String, dynamic>>?;
      if (items != null && items.isNotEmpty) {
        for (var item in items) {
          _editableItems.add({
            'nameController': TextEditingController(text: item['name'] ?? ''),
            'qtyController': TextEditingController(
              text: (item['quantity'] ?? 1).toString(),
            ),
            'priceController': TextEditingController(
              text: (item['price'] ?? '').toString(),
            ),
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
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
      builder: (context) => SafeArea(
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
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedCategory = selected);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF8BBD0),
            onPrimary: Colors.black,
            surface: Color(0xFF2C2C2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amountController.text.isEmpty ||
        double.tryParse(_amountController.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      List<Map<String, dynamic>> finalItems = _editableItems.map((item) {
        return {
          'item_name': item['nameController'].text.trim(),
          'quantity': int.tryParse(item['qtyController'].text) ?? 1,
          'price': double.tryParse(item['priceController'].text) ?? 0.0,
          'category': _selectedCategory,
        };
      }).toList();

      final manualData = {
        'merchant_name': _merchantController.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'total_amount': double.parse(_amountController.text.trim()),
        'tax_amount': null,
        'receipt_category': _selectedCategory,
        'items': finalItems,
      };

      await DatabaseHelper.instance.saveReceiptFromGemini(manualData, '');
      await ref.read(dashboardProvider.notifier).refreshData();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black87,
          builder: (context) => Center(
            child: Lottie.asset(
              'assets/Save_animation.json',
              repeat: false,
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
          ),
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manual Entry',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total Bill Amount',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            '₹',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 40,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IntrinsicWidth(
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}'),
                                ),
                              ],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 56,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(color: Colors.white24),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      GlassContainer(
                        child: Column(
                          children: [
                            GlassTextField(
                              controller: _merchantController,
                              hint: 'Merchant Name',
                              icon: Icons.storefront_outlined,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: const Icon(
                                Icons.calendar_today_outlined,
                                color: Colors.white54,
                              ),
                              title: Text(
                                DateFormat('dd MMM yyyy').format(_selectedDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white24,
                                size: 16,
                              ),
                              onTap: () => _selectDate(context),
                            ),
                            const Divider(color: Colors.white12, height: 1),
                            InkWell(
                              onTap: _showCategoryPicker,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
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

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Line Items',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_editableItems.isNotEmpty) ...[
                        ..._editableItems.asMap().entries.map((entry) {
                          int index = entry.key;
                          var item = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GlassContainer(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GlassTextField(
                                          controller: item['nameController'],
                                          hint: 'Item Name',
                                          icon: Icons.fastfood_outlined,
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
                                  const Divider(
                                    color: Colors.white12,
                                    height: 1,
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: GlassTextField(
                                          controller: item['qtyController'],
                                          hint: 'Qty',
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
                                        child: GlassTextField(
                                          controller: item['priceController'],
                                          hint: 'Total Price',
                                          icon: Icons.currency_rupee_outlined,
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
                      GestureDetector(
                        onTap: _addNewItem,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F7FA).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFE0F7FA).withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: Color(0xFFE0F7FA),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add Line Item',
                                style: TextStyle(
                                  color: Color(0xFFE0F7FA),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: GradientButton(
                  text: 'Save Expense',
                  isLoading: _isSaving,
                  onPressed: _saveExpense,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
