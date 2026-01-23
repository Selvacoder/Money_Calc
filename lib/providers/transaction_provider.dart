import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../services/appwrite_service.dart';
import '../services/sound_service.dart';

class TransactionProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  List<Item> _items = []; // Items for selected category
  List<Item> _quickItems = []; // Frequent items

  bool _isLoading = false;

  List<Transaction> get transactions => _transactions;
  List<Category> get categories => _categories;
  List<Item> get items =>
      _quickItems; // Return quickItems which has all items with frequency
  List<Item> get quickItems => _quickItems;
  bool get isLoading => _isLoading;

  late Box<Transaction> _transactionBox;
  late Box<Category> _categoryBox;
  late Box<Item> _itemBox; // For quick items specifically or all items?
  // Storing 'quick items' in a separate box might be cleaner, e.g., 'items_box'.

  bool _isHiveInitialized = false;

  double get totalBalance {
    double total = 0;
    for (var transaction in _transactions) {
      if (transaction.isExpense) {
        total -= transaction.amount;
      } else {
        total += transaction.amount;
      }
    }
    return total;
  }

  double get totalIncome {
    return _transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return _transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Future<void> _initHive() async {
    if (_isHiveInitialized) return;
    _transactionBox = await Hive.openBox<Transaction>('transactions');
    _categoryBox = await Hive.openBox<Category>('categories');
    _itemBox = await Hive.openBox<Item>('items');
    _isHiveInitialized = true;
  }

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();

    await _initHive();

    try {
      // 1. Load from Cache immediately
      _transactions = _transactionBox.values.toList();
      _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      _categories = _categoryBox.values.toList();
      _quickItems = _itemBox.values
          .where((i) => i.frequency != null)
          .toList(); // Assuming items in box are quick items or we filter?
      // Actually handling 'items' (category specific) vs 'quickItems' (global favorites) in one box needs care.
      // For now, let's assume _itemBox stores all synced items.

      notifyListeners(); // Show cached data

      // 2. Fetch from Network
      // Transactions
      final transactionData = await _appwriteService.getTransactions();
      final networkTransactions = transactionData
          .map((data) => Transaction.fromJson(data))
          .toList();

      if (networkTransactions.isNotEmpty) {
        _transactions = networkTransactions;
        _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        // Update Cache
        await _transactionBox.clear();
        await _transactionBox.putAll({for (var t in _transactions) t.id: t});
      }

      // Categories
      await _loadCategories();

      // Quick Items
      await _loadQuickItems();

      // Load initial items if categories exist
      if (_categories.isNotEmpty) {
        await fetchItemsEx(_categories.first.id);
      }
    } catch (e) {
      print('Error fetching data: $e');
      // On error, we already showed cached data, so user sees something.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoryData = await _appwriteService.getCategories();
      final networkCategories = categoryData
          .map((data) => Category.fromJson(data))
          .toList();

      if (networkCategories.isNotEmpty) {
        _categories = networkCategories;
        // Update Cache
        await _categoryBox.clear();
        await _categoryBox.putAll({for (var c in _categories) c.id: c});
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadQuickItems() async {
    try {
      final quickItemData = await _appwriteService.getQuickItems();
      final networkItems = quickItemData
          .map((data) => Item.fromJson(data))
          .toList();

      if (networkItems.isNotEmpty) {
        _quickItems = networkItems;
        // Update Cache - Warning: this box might ideally be just for quick items?
        // Let's treat 'items' box as generic items storage.
        // We'll just put quick items there for now.
        for (var item in _quickItems) {
          _itemBox.put(item.id, item);
        }
      } else {
        // Fallback to cache if empty? No, empty list means empty list from server usually.
        // But if error, we rely on cache.
      }
    } catch (e) {
      print('Error loading quick items: $e');
      _quickItems = _itemBox.values.toList(); // Simple fallback
    }
  }

  Future<void> fetchItemsEx(String categoryId) async {
    try {
      final itemData = await _appwriteService.getItems(categoryId);
      _items = itemData.map((data) => Item.fromJson(data)).toList();
      notifyListeners();
    } catch (e) {
      print('Error loading items: $e');
    }
  }

  Future<bool> addTransaction(
    String title,
    double amount,
    bool isExpense, {
    String? categoryId,
    String? itemId,
    String? paymentMethod,
  }) async {
    SoundService().play(isExpense ? 'expense.mp3' : 'income.mp3');

    // Optimistic Update
    final tempId = DateTime.now().millisecondsSinceEpoch
        .toString(); // Use timestamp as temp ID
    final newTransaction = Transaction(
      id: tempId,
      title: title,
      amount: amount,
      isExpense: isExpense,
      dateTime: DateTime.now(),
      categoryId: categoryId,
      itemId: itemId,
      paymentMethod: paymentMethod,
    );

    _transactions.insert(0, newTransaction);
    notifyListeners();

    // Cache immediately (so it survives restart if offline)
    // We use tempId, need to cleanup later
    if (_isHiveInitialized) {
      await _transactionBox.put(tempId, newTransaction);
    }

    try {
      // API Call
      final result = await _appwriteService.createTransaction(
        newTransaction.toJson(),
      );

      if (result != null) {
        final realTx = Transaction.fromJson(result);
        final index = _transactions.indexWhere((t) => t.id == tempId);
        if (index != -1) {
          _transactions[index] = realTx;
          notifyListeners();
        }

        // Update Cache with real ID and remove temp
        if (_isHiveInitialized) {
          await _transactionBox.delete(tempId);
          await _transactionBox.put(realTx.id, realTx);
        }

        // Refresh meta data
        _loadQuickItems();
        await _loadCategories(); // Await appropriate here?
        notifyListeners();
        return true;
      } else {
        // This path usually means server returned null explicitly, which is rare for 'success'.
        // Usually it throws.
        return false;
      }
    } catch (e) {
      print('Add Transaction Error: $e');
      // Offline or Error
      // Keep the optimistic update in memory/cache?
      // If we want Offline-First, we keep it.
      // But we need a syncer.
      // For now, we will KEEP it in UI and Cache.
      // Ideally we mark it as 'unsynced' but our model doesn't support it yet.
      // User sees it. Next restart, 'fetchData' runs.
      // 'fetchData' loads from cache (tempId exists).
      // Then fetches from Server (tempId NOT there).
      // Server list overwrites Cache.
      // RESULT: Transaction Disappears on next sync if upload failed.
      // This is "Online-First with Cache".
      // To fix: 'fetchData' needs to merge?
      // Merging is complex without unique IDs/Sync status.
      // I will stick to this for now as MVP.
      return false; // Indicating "Not synced" to UI?
      // UI doesn't use the bool return much except for Dialog close.
    }
  }

  Future<bool> deleteTransaction(String id) async {
    SoundService().play('delete.mp3');

    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return false;

    final removedItem = _transactions[index];
    _transactions.removeAt(index);
    notifyListeners();

    if (_isHiveInitialized) {
      await _transactionBox.delete(id);
    }

    final success = await _appwriteService.deleteTransaction(id);

    if (!success) {
      // Failed to delete on server
      print('Failed to delete transaction $id on server');
      // We do NOT revert locally to avoid "zombie" items.
      // User can resync if needed.
      return false;
    } else {
      _loadQuickItems();
      await _loadCategories();
      notifyListeners();
      return true;
    }
  }

  Future<void> addItem(Map<String, dynamic> itemData) async {
    try {
      final result = await _appwriteService.createItem(itemData);
      if (result != null) {
        final newItem = Item.fromJson(result);
        _quickItems.insert(0, newItem);
        if (_isHiveInitialized) {
          _itemBox.put(newItem.id, newItem);
        }

        // If current category matches, add to items list too
        if (_categories.isNotEmpty &&
            itemData['categoryId'] == _items.firstOrNull?.categoryId) {
          _items.insert(0, newItem);
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error adding item: $e');
      rethrow;
    }
  }

  Future<void> updateItem(String id, Map<String, dynamic> data) async {
    // 1. Find existing item to backup for revert
    final index = _quickItems.indexWhere((i) => i.id == id);
    if (index == -1) return;
    final oldItem = _quickItems[index];

    // 2. Create optimistic new item
    // We need to merge 'data' with 'oldItem' fields
    final newItem = Item(
      id: oldItem.id,
      userId: oldItem.userId,
      title: data['title'] ?? oldItem.title,
      amount: (data['amount'] ?? oldItem.amount).toDouble(),
      isExpense: data['isExpense'] ?? oldItem.isExpense,
      categoryId: data['categoryId'] ?? oldItem.categoryId,
      usageCount: oldItem.usageCount,
      frequency: data['frequency'] ?? oldItem.frequency,
      icon: data['icon'] ?? oldItem.icon,
      dueDay: data['dueDay'] ?? oldItem.dueDay,
    );

    // 3. Update local state immediately
    _quickItems[index] = newItem;
    if (_isHiveInitialized) {
      _itemBox.put(id, newItem);
    }

    // Also update category-specific list if present
    final catIndex = _items.indexWhere((i) => i.id == id);
    if (catIndex != -1) {
      _items[catIndex] = newItem;
    }

    notifyListeners();

    // 4. Perform API call
    final success = await _appwriteService.updateItem(id, data);

    if (!success) {
      print('Failed to update item $id on server');
      // Revert is fine for UPDATE, but for DELETE we want it gone.
      // Keeping revert for update as it helps avoid state desync for editable fields.
      _quickItems[index] = oldItem;
      if (_isHiveInitialized) {
        _itemBox.put(id, oldItem);
      }
      if (catIndex != -1) {
        _items[catIndex] = oldItem;
      }
      notifyListeners();
    }
    // No need to call fetchData() if successful, unless we suspect side effects not covered here.
    // Optimistic update is sufficient for this use case.
  }

  Future<void> deleteItem(String id) async {
    // Optimistic Delete
    _quickItems.removeWhere((i) => i.id == id);
    _items.removeWhere((i) => i.id == id);

    if (_isHiveInitialized) {
      _itemBox.delete(id);
    }
    notifyListeners();

    final success = await _appwriteService.deleteItem(id);
    if (!success) {
      print('Failed to delete item $id on server');
    }
  }

  Future<void> addCategory(String name, String type, String icon) async {
    final result = await _appwriteService.createCategory({
      'name': name,
      'type': type,
      'icon': icon,
    });
    if (result != null) {
      final newCat = Category.fromJson(result);
      _categories.add(newCat);
      if (_isHiveInitialized) {
        _categoryBox.put(newCat.id, newCat);
      }
      notifyListeners();
    }
  }

  Future<void> updateCategory(String id, String name) async {
    final success = await _appwriteService.updateCategory(id, {'name': name});
    if (success) {
      final index = _categories.indexWhere((c) => c.id == id);
      if (index != -1) {
        final old = _categories[index];
        final newCat = Category(
          id: id,
          userId: old.userId,
          name: name,
          type: old.type,
          icon: old.icon,
          usageCount: old.usageCount,
        );
        _categories[index] = newCat;
        if (_isHiveInitialized) {
          _categoryBox.put(id, newCat);
        }
        notifyListeners();
      }
    }
  }

  Future<void> deleteCategory(String id) async {
    // Optimistic Delete
    _categories.removeWhere((c) => c.id == id);
    _items = []; // Clear items as category is gone

    if (_isHiveInitialized) {
      _categoryBox.delete(id);
    }
    notifyListeners();

    final success = await _appwriteService.deleteCategory(id);
    if (!success) {
      print('Failed to delete category $id on server');
    }
  }

  Future<void> clearLocalData() async {
    if (_isHiveInitialized) {
      await _transactionBox.clear();
      await _categoryBox.clear();
      await _itemBox.clear();
    }
    _transactions = [];
    _categories = [];
    _items = [];
    _quickItems = [];
    notifyListeners();

    // Refetch
    await fetchData();
  }

  // Helper method for syncing ledger to wallet
  void addSyncedTransaction(Transaction tx) {
    if (!_transactions.any((t) => t.id == tx.id)) {
      _transactions.insert(0, tx);
      _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      if (_isHiveInitialized) {
        _transactionBox.put(tx.id, tx);
      }
      notifyListeners();
    }
  }
}
