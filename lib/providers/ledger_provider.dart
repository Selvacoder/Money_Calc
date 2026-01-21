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
  bool _isHiveInitialized = false;

  Future<void> _initHive() async {
    if (_isHiveInitialized) return;
    _ledgerBox = await Hive.openBox<LedgerTransaction>('ledger');
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
      final networkTx = data.map((e) => LedgerTransaction.fromJson(e)).toList();

      if (networkTx.isNotEmpty) {
        _ledgerTransactions = networkTx;
        _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        // Update Cache
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
  }) async {
    try {
      // Optimistic Update?
      // Ledger logic is simple, maybe just wait for API?
      // But for consistency with Offline-First, we should ideally support it.
      // However, we need a temp ID.
      // For now, let's keep it Online-Required for Write, but Cache for Read.
      // This is safer for shared ledger correctness.
      // But user asked for Offline-First.
      // If I write to Hive, it's local only.
      // Let's stick to API-first for Ledger writes to avoid sync conflicts with other person.

      final result = await _appwriteService.createLedgerTransaction({
        'name': name,
        'email': phone,
        'amount': amount,
        'description': description,
        'dateTime': DateTime.now().toIso8601String(),
        'isReceived': isReceived,
      });

      if (result != null) {
        final newTx = LedgerTransaction.fromJson(result);
        _ledgerTransactions.insert(0, newTx);

        if (_isHiveInitialized) {
          _ledgerBox.put(newTx.id, newTx);
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error adding ledger tx: $e');
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
