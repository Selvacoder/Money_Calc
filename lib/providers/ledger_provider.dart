import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/ledger_transaction.dart';
import '../services/appwrite_service.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'transaction_provider.dart';

class LedgerProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();

  List<LedgerTransaction> _ledgerTransactions = [];
  bool _isLoading = false;

  List<LedgerTransaction> get ledgerTransactions => _ledgerTransactions;
  bool get isLoading => _isLoading;

  late Box<LedgerTransaction> _ledgerBox;
  late Box<String> _hiddenPeopleBox;
  bool _isHiveInitialized = false;
  List<String> _hiddenPeople = [];

  List<String> get hiddenPeople => _hiddenPeople;

  Future<void> _initHive() async {
    if (_isHiveInitialized) return;
    _ledgerBox = await Hive.openBox<LedgerTransaction>('ledger');
    _hiddenPeopleBox = await Hive.openBox<String>('hidden_people');
    _hiddenPeople = _hiddenPeopleBox.values.toList();
    _isHiveInitialized = true;
  }

  Future<void> fetchLedgerTransactions() async {
    _isLoading = true;
    notifyListeners();

    await _initHive();

    try {
      // 1. Load from Cache
      _ledgerTransactions = _ledgerBox.values.toList();
      _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      notifyListeners(); // Show cached

      // 2. Fetch from Network
      final data = await _appwriteService.getLedgerTransactions();

      if (data != null) {
        // Success (Empty list or Data)
        final networkTx = data
            .map((e) => LedgerTransaction.fromJson(e))
            .toList();
        _ledgerTransactions = networkTx;
        _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        // Update Cache (Clear and Replace)
        await _ledgerBox.clear();
        await _ledgerBox.putAll({for (var t in _ledgerTransactions) t.id: t});
      }
    } catch (e) {
      print('Error fetching ledger: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addLedgerTransaction(
    String name,
    String? phone,
    double amount,
    String description, {
    required bool isReceived,
    required String currentUserId,
    required String currentUserName,
    required String currentUserPhone,
  }) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    // 1. Create and Add Optimistic Transaction
    final optimisticTx = LedgerTransaction(
      id: tempId,
      senderId: isReceived ? 'other' : currentUserId, // Simplified ID logic
      senderName: isReceived ? name : currentUserName,
      senderPhone: isReceived ? (phone ?? '') : currentUserPhone,
      receiverName: isReceived ? currentUserName : name,
      receiverPhone: isReceived ? currentUserPhone : (phone ?? ''),
      amount: amount,
      description: description,
      dateTime: now,
    );

    _ledgerTransactions.insert(0, optimisticTx);
    notifyListeners();

    try {
      final result = await _appwriteService.createLedgerTransaction({
        'name': name,
        'email': phone,
        'amount': amount,
        'description': description,
        'dateTime': now.toIso8601String(),
        'isReceived': isReceived,
      });

      if (result != null) {
        // Replace optimistic with real
        final realTx = LedgerTransaction.fromJson(result);
        final index = _ledgerTransactions.indexWhere((t) => t.id == tempId);
        if (index != -1) {
          _ledgerTransactions[index] = realTx;
        } else {
          // Should not happen, but fallback
          _ledgerTransactions.add(realTx);
          _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        }

        if (_isHiveInitialized) {
          _ledgerBox.put(realTx.id, realTx);
        }
        notifyListeners();
        return true;
      } else {
        // Failed: Remove optimistic
        _ledgerTransactions.removeWhere((t) => t.id == tempId);
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Error adding ledger tx: $e');
      _ledgerTransactions.removeWhere((t) => t.id == tempId);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteLedgerTransaction(String id) async {
    final success = await _appwriteService.deleteLedgerTransaction(id);
    if (success) {
      _ledgerTransactions.removeWhere((t) => t.id == id);
      if (_isHiveInitialized) {
        _ledgerBox.delete(id);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  // ... (fetchLedgerTransactions)

  // ... (addLedgerTransaction)

  // ... (deleteLedgerTransaction)

  Future<void> hidePerson(String name) async {
    if (!_hiddenPeople.contains(name)) {
      _hiddenPeople.add(name);
      await _hiddenPeopleBox.add(name);
      notifyListeners();
    }
  }

  Future<void> unhidePerson(String name) async {
    if (_hiddenPeople.contains(name)) {
      _hiddenPeople.remove(name);

      // Hive doesn't support easy remove mostly by value without index loops
      // Simple way: clear and rewrite or find key.
      // Since it's a simple list, let's just clear and rewriting or find key.

      final Map<dynamic, String> boxMap = _hiddenPeopleBox
          .toMap()
          .cast<dynamic, String>();
      dynamic keyToDelete;
      boxMap.forEach((key, value) {
        if (value == name) {
          keyToDelete = key;
        }
      });

      if (keyToDelete != null) {
        await _hiddenPeopleBox.delete(keyToDelete);
      }

      notifyListeners();
    }
  }

  // Edit Person (Batch Update)
  Future<bool> updatePerson({
    required String oldName,
    required String oldPhone,
    required String newName,
    required String newPhone,
  }) async {
    final success = await _appwriteService.updateLedgerPerson(
      oldName: oldName,
      oldPhone: oldPhone,
      newName: newName,
      newPhone: newPhone,
    );

    if (success) {
      // Refresh to get updated transactions
      // Or we could try to update local state manually, but it's complex with many transactions.
      await fetchLedgerTransactions();
      return true;
    }
    return false;
  }

  // Delete Person (Batch Delete)
  Future<bool> deletePerson({
    required String name,
    required String phone,
  }) async {
    final success = await _appwriteService.deleteLedgerPerson(
      name: name,
      phone: phone,
    );

    if (success) {
      // Refresh to clear deleted transactions
      await fetchLedgerTransactions();
      return true;
    }
    return false;
  }

  // Sync Logic
  Future<void> syncLedgerToWallet(
    TransactionProvider transactionProvider,
    String currentUserPhone,
    List<Category> categories,
  ) async {
    // This logic mimics the one in _HomePageState._syncLedgerToWallet
    // It requires access to TransactionProvider to check existence and add new ones.

    for (var ledgerTx in _ledgerTransactions) {
      if (ledgerTx.dateTime.isBefore(
        DateTime.now().subtract(const Duration(minutes: 5)),
      )) {
        continue;
      }

      final isSynced = transactionProvider.transactions.any(
        (t) => t.ledgerId == ledgerTx.id,
      );

      if (!isSynced) {
        final normUserContact = _normalizePhone(currentUserPhone);
        final normSender = _normalizePhone(ledgerTx.senderPhone);
        final normReceiver = _normalizePhone(ledgerTx.receiverPhone);

        final isSender = normSender == normUserContact;
        final isReceiver = normReceiver == normUserContact;

        if (!isSender && !isReceiver) continue;
        if (isSender && isReceiver) continue;

        String title;
        bool isExpense;
        String otherName;

        if (isSender) {
          isExpense = true;
          otherName = ledgerTx.receiverName;
          title = 'Lent to $otherName';
        } else {
          isExpense = false;
          otherName = ledgerTx.senderName;
          title = 'Borrowed from $otherName';
        }

        // Find Category 'Others'
        String? categoryId;
        try {
          final targetType = isExpense ? 'expense' : 'income';
          final category = categories.firstWhere(
            (c) => c.name.toLowerCase() == 'others' && c.type == targetType,
            orElse: () => categories.firstWhere(
              (c) => c.type == targetType,
              orElse: () => categories.first,
            ),
          );
          categoryId = category.id;
        } catch (_) {}

        if (categoryId != null) {
          try {
            final transactionData = {
              'title': title,
              'amount': ledgerTx.amount,
              'isExpense': isExpense,
              'dateTime': ledgerTx.dateTime.toIso8601String(),
              'categoryId': categoryId,
              'ledgerId': ledgerTx.id,
            };

            final result = await _appwriteService.createTransaction(
              transactionData,
            );
            if (result != null) {
              final newTx = Transaction.fromJson(result);
              transactionProvider.addSyncedTransaction(newTx);
            }
          } catch (e) {
            print("Sync Error for tx ${ledgerTx.id}: $e");
          }
        }
      }
    }
  }

  String _normalizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }
}
