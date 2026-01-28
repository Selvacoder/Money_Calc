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
  List<LedgerTransaction> _incomingRequests = [];
  List<LedgerTransaction> _outgoingRequests = [];
  bool _isLoading = false;

  List<LedgerTransaction> get ledgerTransactions => _ledgerTransactions;
  List<LedgerTransaction> get incomingRequests => _incomingRequests;
  List<LedgerTransaction> get outgoingRequests => _outgoingRequests;

  bool get isLoading => _isLoading;

  late Box<LedgerTransaction> _ledgerBox;
  late Box<String> _hiddenPeopleBox;
  bool _isHiveInitialized = false;
  List<String> _hiddenPeople = [];

  List<String> get hiddenPeople => _hiddenPeople;

  String? _currentUserId;

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

    // Ensure we have current user ID for filtering
    if (_currentUserId == null) {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        _currentUserId = user['userId'];
      }
    }

    try {
      // 1. Load from Cache (Temporary, might show stale if we don't differentiate pending/confirmed in cache structure easily)
      // For now, load all and filter
      final cached = _ledgerBox.values.toList();
      _processTransactions(cached);
      notifyListeners(); // Show cached

      // 2. Fetch from Network
      final data = await _appwriteService.getLedgerTransactions();

      if (data != null) {
        // Success
        final networkTx = data
            .map((e) => LedgerTransaction.fromJson(e))
            .toList();

        _processTransactions(networkTx);

        // Update Cache (Clear and Replace)
        await _ledgerBox.clear();
        await _ledgerBox.putAll({for (var t in networkTx) t.id: t});
      }
    } catch (e) {
      print('Error fetching ledger: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _processTransactions(List<LedgerTransaction> all) {
    _ledgerTransactions = [];
    _incomingRequests = [];
    _outgoingRequests = [];

    // Sort valid date desc first
    all.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    for (var tx in all) {
      if (tx.status == 'confirmed') {
        _ledgerTransactions.add(tx);
      } else if (tx.status == 'pending') {
        // If receiverId matches me, it's an incoming request
        if (_currentUserId != null && tx.receiverId == _currentUserId) {
          _incomingRequests.add(tx);
        } else if (tx.senderId == _currentUserId) {
          // If I am sender, it's an outgoing request
          _outgoingRequests.add(tx);
        } else {
          // Logic fallback: If I'm not receiverId but phone matches receiverPhone?
          // For now, rely on ID if available.
          // If ID not available (e.g. legacy data or no ID link), maybe skip or put in outgoing?
          _outgoingRequests.add(tx);
        }
      }
    }
  }

  Future<String?> addLedgerTransaction(
    String name,
    String? phone,
    double amount,
    String description, {
    required bool isReceived,
    required String currentUserId,
    required String currentUserName,
    required String currentUserPhone,
    String? currentUserEmail,
  }) async {
    _currentUserId = currentUserId;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    String status = 'confirmed';
    if (phone != null && phone.isNotEmpty && !phone.startsWith('local:')) {
      // Optimistically assume pending if it's a real phone number
      status = 'pending';
    }

    // CRITICAL FIX: Swap sender/receiver based on isReceived
    // isReceived = true  -> "You Got" -> Other person GAVE, you RECEIVED
    //                       Sender = Other person, Receiver = Current user
    // isReceived = false -> "You Gave" -> You GAVE, other person RECEIVED
    //                       Sender = Current user, Receiver = Other person

    final String actualSenderName;
    final String? actualSenderPhone;
    final String actualReceiverName;
    final String? actualReceiverPhone;

    if (isReceived) {
      // "You Got" - Other person is sender, you are receiver
      actualSenderName = name;
      actualSenderPhone = phone;
      actualReceiverName = currentUserName;
      actualReceiverPhone = currentUserPhone;
    } else {
      // "You Gave" - You are sender, other person is receiver
      actualSenderName = currentUserName;
      actualSenderPhone = currentUserPhone;
      actualReceiverName = name;
      actualReceiverPhone = phone;
    }

    // 1. Create and Add Optimistic Transaction
    final optimisticTx = LedgerTransaction(
      id: tempId,
      senderId: currentUserId, // Creator is always current user
      senderName: actualSenderName,
      senderPhone: actualSenderPhone ?? '',
      receiverName: actualReceiverName,
      receiverPhone: actualReceiverPhone,
      amount: amount.abs(), // Always store positive amount
      description: description,
      dateTime: now,
      status: status,
    );

    if (status == 'confirmed') {
      _ledgerTransactions.insert(0, optimisticTx);
    } else {
      _outgoingRequests.insert(0, optimisticTx);
    }
    notifyListeners();

    try {
      final result = await _appwriteService.createLedgerTransaction({
        'senderName': actualSenderName,
        'senderPhone': actualSenderPhone ?? '',
        'receiverName': actualReceiverName,
        'receiverPhone': actualReceiverPhone ?? '',
        'amount': amount.abs(), // Always store positive
        'description': description,
        'dateTime': now.toIso8601String(),
      });

      if (result != null) {
        // Replace optimistic with real
        final realTx = LedgerTransaction.fromJson(result);

        // Remove optimistic from wherever it was put
        if (status == 'confirmed') {
          _ledgerTransactions.removeWhere((t) => t.id == tempId);
        } else {
          _outgoingRequests.removeWhere((t) => t.id == tempId);
        }

        // Add real based on ACTUAL status
        if (realTx.status == 'confirmed') {
          _ledgerTransactions.add(realTx);
          _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        } else {
          _outgoingRequests.add(realTx);
          _outgoingRequests.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        }

        if (_isHiveInitialized) {
          _ledgerBox.put(realTx.id, realTx);
        }
        notifyListeners();
        return null; // Success
      } else {
        // Failed
        if (status == 'confirmed') {
          _ledgerTransactions.removeWhere((t) => t.id == tempId);
        } else {
          _outgoingRequests.removeWhere((t) => t.id == tempId);
        }
        notifyListeners();
        return 'Failed to create transaction (Unknown error)';
      }
    } catch (e) {
      print('Error adding ledger tx: $e');
      _ledgerTransactions.removeWhere((t) => t.id == tempId);
      _outgoingRequests.removeWhere((t) => t.id == tempId);
      notifyListeners();
      return 'Error: $e';
    }
  }

  Future<bool> acceptLedgerTransaction(LedgerTransaction tx) async {
    // Optimistic update
    _incomingRequests.remove(tx);
    // Create a modified copy with confirmed status
    // Since Hive objects are immutable/adapters, better create new instance or assume internal update if mutable (not Recoomended)
    // We'll create a new instance via hack or just waiting.
    // Actually, let's wait for server response to be safe, but show loading?
    // User wants "if they accept it will add confirmed".

    // We add it to ledgerTransactions locally
    // But we need to update the status in the backend.

    try {
      final success = await _appwriteService.updateLedgerTransactionStatus(
        tx.id,
        'confirmed',
      );
      if (success) {
        // Re-fetch to get clean state or manually move
        await fetchLedgerTransactions();
        return true;
      }
      return false;
    } catch (e) {
      print('Error accepting transaction: $e');
      return false;
    }
  }

  Future<bool> rejectLedgerTransaction(String id) async {
    try {
      final success = await _appwriteService.updateLedgerTransactionStatus(
        id,
        'rejected',
      );
      if (success) {
        await fetchLedgerTransactions();
        return true;
      }
      return false;
    } catch (e) {
      print('Error rejecting transaction: $e');
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
