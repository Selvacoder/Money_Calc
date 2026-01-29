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
  List<LedgerTransaction> _notes = [];
  bool _isLoading = false;

  List<LedgerTransaction> get ledgerTransactions => _ledgerTransactions;
  List<LedgerTransaction> get incomingRequests => _incomingRequests;
  List<LedgerTransaction> get outgoingRequests => _outgoingRequests;
  List<LedgerTransaction> get notes => _notes;
  bool get isLoading => _isLoading;

  late Box<LedgerTransaction> _ledgerBox;
  late Box<String> _hiddenPeopleBox;
  bool _isHiveInitialized = false;
  List<String> _hiddenPeople = [];
  List<String> get hiddenPeople => _hiddenPeople;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;

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

    if (_currentUserId == null) {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        _currentUserId = user['userId'];
      }
    }

    try {
      final cached = _ledgerBox.values.toList();
      _processTransactions(cached);
      notifyListeners();

      final data = await _appwriteService.getLedgerTransactions();
      if (data != null) {
        final networkTx = data
            .map((e) => LedgerTransaction.fromJson(e))
            .toList();
        _processTransactions(networkTx);
        await _ledgerBox.clear();
        await _ledgerBox.putAll({for (var t in networkTx) t.id: t});
      }
    } catch (e) {
      debugPrint('Error fetching ledger: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _processTransactions(List<LedgerTransaction> all) {
    _ledgerTransactions = [];
    _incomingRequests = [];
    _outgoingRequests = [];
    _notes = [];

    all.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    for (var tx in all) {
      if (tx.status == 'confirmed') {
        _ledgerTransactions.add(tx);
      } else if (tx.status == 'notes') {
        _notes.add(tx);
      } else if (tx.status == 'pending') {
        if (_currentUserId != null && tx.receiverId == _currentUserId) {
          _incomingRequests.add(tx);
        } else if (tx.senderId == _currentUserId) {
          _outgoingRequests.add(tx);
        } else {
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
    String? customStatus,
  }) async {
    _currentUserId = currentUserId;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    String status = customStatus ?? 'confirmed';
    if (customStatus == null &&
        phone != null &&
        phone.isNotEmpty &&
        !phone.startsWith('local:')) {
      status = 'pending';
    }

    // Standardize naming to avoid "Me giving to Me" messiness
    final displayOtherName =
        (name.trim().toLowerCase() == currentUserName.trim().toLowerCase() ||
            name.trim().toLowerCase() == 'me')
        ? 'Self'
        : name.trim();

    final String actualSenderName;
    final String? actualSenderPhone;
    final String? actualSenderId;
    final String actualReceiverName;
    final String? actualReceiverPhone;
    final String? actualReceiverId;

    if (isReceived) {
      // "You Got" - Other person is sender, you are receiver
      actualSenderName = displayOtherName;
      actualSenderPhone = phone;
      actualSenderId = null; // We don't know other person's ID unless linked
      actualReceiverName = currentUserName;
      actualReceiverPhone = currentUserPhone;
      actualReceiverId = currentUserId;
    } else {
      // "You Gave" - You are sender, other person is receiver
      actualSenderName = currentUserName;
      actualSenderPhone = currentUserPhone;
      actualSenderId = currentUserId;
      actualReceiverName = displayOtherName;
      actualReceiverPhone = phone;
      actualReceiverId = null;
    }

    final optimisticTx = LedgerTransaction(
      id: tempId,
      senderId: actualSenderId ?? '',
      senderName: actualSenderName,
      senderPhone: actualSenderPhone ?? '',
      receiverName: actualReceiverName,
      receiverPhone: actualReceiverPhone,
      receiverId: actualReceiverId,
      amount: amount.abs(),
      description: description,
      dateTime: now,
      status: status,
    );

    // OPTIMISTIC UPDATE

    if (status == 'confirmed') {
      _ledgerTransactions.insert(0, optimisticTx);
    } else if (status == 'notes') {
      _notes.insert(0, optimisticTx);
    } else {
      // Pending
      _outgoingRequests.insert(0, optimisticTx);
    }
    notifyListeners();

    try {
      final result = await _appwriteService.createLedgerTransaction({
        'senderName': actualSenderName,
        'senderPhone': actualSenderPhone ?? '',
        'senderId': actualSenderId ?? '',
        'receiverName': actualReceiverName,
        'receiverPhone': actualReceiverPhone ?? '',
        'receiverId': actualReceiverId ?? '',
        'amount': amount.abs(),
        'description': description,
        'dateTime': now.toIso8601String(),
        'status': status,
      });

      if (result != null) {
        LedgerTransaction realTx;
        try {
          realTx = LedgerTransaction.fromJson(result);
        } catch (e) {
          print('DEBUG: JSON Parse Error: $e');
          _removeFromLocal(tempId, status);
          notifyListeners();
          return 'JSON Parse Failed: $e';
        }

        // Remove optimistic
        if (status == 'confirmed') {
          _ledgerTransactions.removeWhere((t) => t.id == tempId);
        } else if (status == 'notes') {
          _notes.removeWhere((t) => t.id == tempId);
        } else {
          _outgoingRequests.removeWhere((t) => t.id == tempId);
        }

        // Add real
        if (realTx.status == 'confirmed') {
          _ledgerTransactions.add(realTx);
          _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        } else if (realTx.status == 'notes') {
          _notes.add(realTx);
          _notes.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        } else {
          // Pending
          _outgoingRequests.add(realTx);
          _outgoingRequests.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        }

        if (_isHiveInitialized) {
          _ledgerBox.put(realTx.id, realTx);
        }
        notifyListeners();
        return null;
      } else {
        // print('DEBUG: Backend returned NULL result');
        _removeFromLocal(tempId, status);
        notifyListeners();
        return 'Failed to create transaction';
      }
    } catch (e) {
      _removeFromLocal(tempId, status);
      notifyListeners();
      return 'Error: $e';
    }
  }

  void _removeFromLocal(String id, String status) {
    if (status == 'confirmed') {
      _ledgerTransactions.removeWhere((t) => t.id == id);
    } else if (status == 'notes') {
      _notes.removeWhere((t) => t.id == id);
    } else {
      _outgoingRequests.removeWhere((t) => t.id == id);
    }
  }

  Future<bool> acceptLedgerTransaction(LedgerTransaction tx) async {
    try {
      final success = await _appwriteService.updateLedgerTransactionStatus(
        tx.id,
        'confirmed',
      );
      if (success) {
        await fetchLedgerTransactions();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error accepting transaction: $e');
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
      debugPrint('Error rejecting transaction: $e');
      return false;
    }
  }

  Future<bool> deleteLedgerTransaction(String id) async {
    final success = await _appwriteService.deleteLedgerTransaction(id);
    if (success) {
      _ledgerTransactions.removeWhere((t) => t.id == id);
      _notes.removeWhere((t) => t.id == id);
      _outgoingRequests.removeWhere((t) => t.id == id);
      if (_isHiveInitialized) {
        _ledgerBox.delete(id);
      }
      notifyListeners();
      return true;
    }
    return false;
  }

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
      final Map<dynamic, String> boxMap = _hiddenPeopleBox
          .toMap()
          .cast<dynamic, String>();
      dynamic keyToDelete;
      boxMap.forEach((key, value) {
        if (value == name) keyToDelete = key;
      });
      if (keyToDelete != null) await _hiddenPeopleBox.delete(keyToDelete);
      notifyListeners();
    }
  }

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
      await fetchLedgerTransactions();
      return true;
    }
    return false;
  }

  Future<bool> deletePerson({
    required String name,
    required String phone,
  }) async {
    final success = await _appwriteService.deleteLedgerPerson(
      name: name,
      phone: phone,
    );
    if (success) {
      await fetchLedgerTransactions();
      return true;
    }
    return false;
  }

  Future<void> syncLedgerToWallet(
    TransactionProvider transactionProvider,
    String currentUserPhone,
    List<Category> categories,
  ) async {
    for (var ledgerTx in _ledgerTransactions) {
      if (ledgerTx.dateTime.isBefore(
        DateTime.now().subtract(const Duration(minutes: 5)),
      ))
        continue;
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
            final result = await _appwriteService.createTransaction({
              'title': title,
              'amount': ledgerTx.amount,
              'isExpense': isExpense,
              'dateTime': ledgerTx.dateTime.toIso8601String(),
              'categoryId': categoryId,
              'ledgerId': ledgerTx.id,
            });
            if (result != null) {
              transactionProvider.addSyncedTransaction(
                Transaction.fromJson(result),
              );
            }
          } catch (e) {
            debugPrint("Sync Error for tx ${ledgerTx.id}: $e");
          }
        }
      }
    }
  }

  List<LedgerTransaction> getTransactionsForPerson(
    String personName,
    String? personPhone,
    String currentUserId,
    List<String> myIdentities,
  ) {
    // Combine all sources: Confirmed + Notes + Outgoing(Pending) + Incoming(Pending)
    final all = [
      ..._ledgerTransactions,
      ..._notes,
      ..._outgoingRequests,
      ..._incomingRequests,
    ];

    return all.where((t) {
      // 1. Check if ANY participant matches the target person (Name OR Phone)
      final isSender =
          t.senderName == personName ||
          _arePhonesEqual(t.senderPhone, personPhone);
      final isReceiver =
          t.receiverName == personName ||
          _arePhonesEqual(t.receiverPhone, personPhone);

      if (!isSender && !isReceiver) return false;

      // 2. Ensuring the OTHER participant is ME
      // If target is sender, I must be receiver.
      // If target is receiver, I must be sender.
      if (isSender) {
        return t.receiverId == currentUserId ||
            myIdentities.any((id) => _arePhonesEqual(t.receiverPhone, id));
      } else {
        return t.senderId == currentUserId ||
            myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id));
      }
    }).toList();
  }

  bool _arePhonesEqual(String? p1, String? p2) {
    if (p1 == null || p2 == null) return false;
    return _normalizePhone(p1) == _normalizePhone(p2);
  }

  String _normalizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }
}
