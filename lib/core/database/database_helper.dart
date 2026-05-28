import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static const _databaseName = "Folia.db";
  static const _databaseVersion = 1;
  final _uuid = const Uuid();

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _onCreate(Database db, int version) async {
    // 1. Categories
    await db.execute('''
      CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color_hex TEXT
      )
    ''');

    // Budgets Table
    await db.execute('''
      CREATE TABLE budgets (
          id TEXT PRIMARY KEY,
          category_name TEXT NOT NULL UNIQUE,
          monthly_limit REAL NOT NULL
      )
    ''');

    // CLEANED: Receipts
    await db.execute('''
      CREATE TABLE receipts (
          id TEXT PRIMARY KEY,
          merchant_name TEXT NOT NULL,
          purchase_date TEXT NOT NULL,
          total_amount REAL NOT NULL,
          tax_amount REAL,
          category_id TEXT, 
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Line Items
    await db.execute('''
      CREATE TABLE line_items (
          id TEXT PRIMARY KEY,
          receipt_id TEXT NOT NULL,
          item_name TEXT NOT NULL,
          quantity INTEGER DEFAULT 1,
          price REAL NOT NULL,
          category_id TEXT,
          FOREIGN KEY (receipt_id) REFERENCES receipts (id) ON DELETE CASCADE,
          FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Splits
    await db.execute('''
      CREATE TABLE line_item_splits (
          id TEXT PRIMARY KEY,
          line_item_id TEXT NOT NULL,
          user_name TEXT NOT NULL,
          owed_amount REAL NOT NULL,
          FOREIGN KEY (line_item_id) REFERENCES line_items (id) ON DELETE CASCADE
      )
    ''');

    // Seed Categories
    final defaultCategories = [
      {'id': _uuid.v4(), 'name': 'Groceries', 'color_hex': '#E1BEE7'},
      {'id': _uuid.v4(), 'name': 'Food & Dining', 'color_hex': '#B2DFDB'},
      {'id': _uuid.v4(), 'name': 'Travel & Transport', 'color_hex': '#FFCCBC'},
      {'id': _uuid.v4(), 'name': 'Shopping & Retail', 'color_hex': '#F8BBD0'},
      {'id': _uuid.v4(), 'name': 'Electronics', 'color_hex': '#FFF9C4'},
      {'id': _uuid.v4(), 'name': 'Health & Pharmacy', 'color_hex': '#C8E6C9'},
      {'id': _uuid.v4(), 'name': 'Home & Maintenance', 'color_hex': '#D7CCC8'},
      {'id': _uuid.v4(), 'name': 'Entertainment', 'color_hex': '#BBDEFB'},
      {'id': _uuid.v4(), 'name': 'Utility Bills', 'color_hex': '#B3E5FC'},
      {'id': _uuid.v4(), 'name': 'Other', 'color_hex': '#CFD8DC'},
    ];

    for (var cat in defaultCategories) {
      await db.insert('categories', cat);
    }
  }

  // RECEIPT LOGIC
  Future<void> saveReceiptFromGemini(
    Map<String, dynamic> data,
    String imagePath,
  ) async {
    final db = await instance.database;
    String normalizeDate(String inputDate) {
      try {
        DateTime.parse(inputDate);
        return inputDate;
      } catch (e) {
        final parts = inputDate.split(RegExp(r'[-/]'));
        if (parts.length == 3) return '${parts[2]}-${parts[1]}-${parts[0]}';
        return DateTime.now().toIso8601String().split('T')[0];
      }
    }

    await db.transaction((txn) async {
      Future<String?> getCategoryId(String categoryName) async {
        final maps = await txn.query(
          'categories',
          columns: ['id'],
          where: 'name = ?',
          whereArgs: [categoryName],
        );
        if (maps.isNotEmpty) return maps.first['id'] as String;
        final otherMap = await txn.query(
          'categories',
          columns: ['id'],
          where: 'name = ?',
          whereArgs: ['Other'],
        );
        return otherMap.isNotEmpty ? otherMap.first['id'] as String : null;
      }

      final String receiptId = _uuid.v4();
      final String? masterCategoryId = await getCategoryId(
        data['receipt_category'] ?? 'Other',
      );
      final cleanDate = normalizeDate(data['date'] ?? '');

      await txn.insert('receipts', {
        'id': receiptId,
        'merchant_name': data['merchant_name'],
        'purchase_date': cleanDate,
        'total_amount': data['total_amount'],
        'tax_amount': data['tax_amount'],
        'category_id': masterCategoryId,
      });

      if (data['items'] != null && data['items'] is List) {
        for (var item in data['items']) {
          final String itemId = _uuid.v4();
          final String? itemCategoryId = await getCategoryId(
            item['category'] ?? 'Other',
          );

          await txn.insert('line_items', {
            'id': itemId,
            'receipt_id': receiptId,
            'item_name': item['item_name'],
            'quantity': item['quantity'] ?? 1,
            'price': item['price'],
            'category_id': itemCategoryId,
          });
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllReceipts() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT receipts.*, categories.name as category_name 
      FROM receipts
      LEFT JOIN categories ON receipts.category_id = categories.id
      ORDER BY receipts.purchase_date DESC
    ''');
  }

  Future<int> deleteReceipt(String id) async {
    final db = await instance.database;
    return await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getLineItems(String receiptId) async {
    final db = await instance.database;
    return await db.query(
      'line_items',
      where: 'receipt_id = ?',
      whereArgs: [receiptId],
    );
  }

  // SPLIT LOGIC
  Future<List<Map<String, dynamic>>> getReceiptsWithLineItems() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT r.*, c.name as category_name
      FROM receipts r
      LEFT JOIN categories c ON r.category_id = c.id
      WHERE EXISTS (SELECT 1 FROM line_items l WHERE l.receipt_id = r.id)
      ORDER BY r.purchase_date DESC
    ''');
  }

  // Fetches the exact item breakdown for a saved bill so we can share it
  Future<List<Map<String, dynamic>>> getSavedSplitsForReceipt(
    String receiptId,
  ) async {
    final db = await instance.database;
    return await db.rawQuery(
      '''
      SELECT s.user_name, s.owed_amount, l.item_name, l.quantity
      FROM line_item_splits s
      JOIN line_items l ON s.line_item_id = l.id
      WHERE l.receipt_id = ?
    ''',
      [receiptId],
    );
  }

  Future<void> saveSplits(
    String receiptId,
    List<Map<String, dynamic>> splits,
  ) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.rawDelete(
        '''
        DELETE FROM line_item_splits 
        WHERE line_item_id IN (SELECT id FROM line_items WHERE receipt_id = ?)
      ''',
        [receiptId],
      );

      for (var split in splits) {
        await txn.insert('line_item_splits', {
          'id': _uuid.v4(),
          'line_item_id': split['line_item_id'],
          'user_name': split['user_name'],
          'owed_amount': split['owed_amount'],
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getDetailedBalances() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT s.user_name, SUM(s.owed_amount) as amount_owed_for_bill, r.id as receipt_id, r.merchant_name, r.purchase_date
      FROM line_item_splits s
      JOIN line_items l ON s.line_item_id = l.id
      JOIN receipts r ON l.receipt_id = r.id
      WHERE LOWER(s.user_name) != 'me'
      GROUP BY LOWER(s.user_name), r.id
      HAVING amount_owed_for_bill > 0
      ORDER BY r.purchase_date DESC
    ''');
  }

  Future<void> settleBalance(String userName) async {
    final db = await instance.database;
    await db.delete(
      'line_item_splits',
      where: 'LOWER(user_name) = ?',
      whereArgs: [userName.toLowerCase()],
    );
  }

  // Mark a specific bill as paid for a specific friend
  Future<void> settleSpecificBill(String userName, String receiptId) async {
    final db = await instance.database;
    await db.rawDelete(
      '''
      DELETE FROM line_item_splits 
      WHERE LOWER(user_name) = ? 
      AND line_item_id IN (
        SELECT id FROM line_items WHERE receipt_id = ?
      )
    ''',
      [userName.toLowerCase(), receiptId],
    );
  }

  Future<List<Map<String, dynamic>>> getSplitHistory() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT DISTINCT r.id, r.merchant_name, r.purchase_date, r.total_amount
      FROM receipts r
      JOIN line_items l ON r.id = l.receipt_id
      JOIN line_item_splits s ON l.id = s.line_item_id
      ORDER BY r.purchase_date DESC
    ''');
  }

  // BUDGET LOGIC
  Future<void> setBudget(String categoryName, double limit) async {
    final db = await instance.database;

    await db.rawInsert(
      '''
      INSERT INTO budgets (id, category_name, monthly_limit)
      VALUES (?, ?, ?)
      ON CONFLICT(category_name) DO UPDATE SET monthly_limit = excluded.monthly_limit
    ''',
      [_uuid.v4(), categoryName, limit],
    );
  }

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await instance.database;
    return await db.query('budgets');
  }

  // BUDGET LOGIC
  Future<void> deleteBudget(String categoryName) async {
    final db = await instance.database;
    await db.delete(
      'budgets',
      where: 'category_name = ?',
      whereArgs: [categoryName],
    );
  }

  Future<void> updateReceipt(int id, Map<String, dynamic> data) async {
    final db = await database; // Ensure this matches your variable name

    // 1. Update the main receipt details
    await db.update(
      'receipts',
      {
        'merchant_name': data['merchant_name'],
        'purchase_date': data['date'],
        'total_amount': data['total_amount'],
        'category_name': data['receipt_category'],
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // 2. Clear old items and insert updated items
    await db.delete('receipt_items', where: 'receipt_id = ?', whereArgs: [id]);

    for (var item in data['items']) {
      await db.insert('receipt_items', {
        'receipt_id': id,
        'item_name': item['item_name'],
        'quantity': item['quantity'],
        'price': item['price'],
      });
    }
  }
}
