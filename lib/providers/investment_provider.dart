import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/investment.dart';
import '../models/investment_transaction.dart';
import '../services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';

class InvestmentProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();

  List<Investment> _investments = [];
  List<InvestmentTransaction> _transactions = [];
  bool _isLoading = false;

  bool _hasMoreInvestments = true;
  bool _hasMoreTransactions = true;
  String? _lastTransactionId;

  List<Investment> get investments => _investments;
  List<InvestmentTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get hasMoreInvestments => _hasMoreInvestments;
  bool get hasMoreTransactions => _hasMoreTransactions;

  late Box<Investment> _investmentBox;
  late Box<InvestmentTransaction> _transactionBox;
  bool _isHiveInitialized = false;

  double get totalInvestedValue {
    return _investments.fold(0.0, (sum, i) => sum + i.investedAmount);
  }

  double get totalCurrentValue {
    return _investments.fold(0.0, (sum, i) => sum + i.currentAmount);
  }

  double get totalProfitLoss => totalCurrentValue - totalInvestedValue;

  Future<void> _initHive() async {
    if (_isHiveInitialized) return;
    _investmentBox = await Hive.openBox<Investment>('investments');
    _transactionBox = await Hive.openBox<InvestmentTransaction>(
      'investment_transactions',
    );
    _isHiveInitialized = true;
  }

  Future<void> fetchInvestments() async {
    _isLoading = true;
    notifyListeners();

    await _initHive();

    try {
      // 1. Load from Cache
      _investments = _investmentBox.values.toList();
      _investments.sort((a, b) => b.investedAmount.compareTo(a.investedAmount));

      _transactions = _transactionBox.values.toList();
      _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      notifyListeners();

      // 2. Fetch from Network
      final invData = await _appwriteService.getInvestments();
      final networkInv = invData.map((d) => Investment.fromJson(d)).toList();

      if (networkInv.isNotEmpty) {
        _investments = networkInv;
        _investments.sort(
          (a, b) => b.investedAmount.compareTo(a.investedAmount),
        );
        _hasMoreInvestments = networkInv.length >= 25;
        await _investmentBox.clear();
        await _investmentBox.putAll({for (var i in _investments) i.id: i});
      } else {
        _hasMoreInvestments = false;
      }

      if (invData.isNotEmpty) {
        final txData = await _appwriteService.getInvestmentTransactions();
        final networkTx = txData
            .map((d) => InvestmentTransaction.fromJson(d))
            .toList();

        if (networkTx.isNotEmpty) {
          _transactions = networkTx;
          _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          _lastTransactionId = _transactions.last.id;
          _hasMoreTransactions = networkTx.length >= 25;
          await _transactionBox.clear();
          await _transactionBox.putAll({for (var t in _transactions) t.id: t});
        } else {
          _hasMoreTransactions = false;
        }
      } else {
        debugPrint(
          'DEBUG: fetchInvestments - No investments found, skipping transaction fetch to avoid 401.',
        );
      }
    } catch (e) {
      if (e is! AppwriteException || e.code != 401) {
        print('Error fetching investments: $e');
      }
    } finally {
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> addInvestment(
    String name,
    String type,
    double amount,
    double quantity,
  ) async {
    // 1. Check for Duplicate
    final normalizedName = name.trim().toLowerCase();
    final existingIndex = _investments.indexWhere(
      (i) => i.name.trim().toLowerCase() == normalizedName,
    );

    if (existingIndex != -1) {
      // Merge with existing
      final existingParams = _investments[existingIndex];
      // Calculate derived price per unit (Amount is Total Invested here)
      final pricePerUnit = quantity > 0 ? amount / quantity : 0.0;

      await addTransaction(
        existingParams.id,
        'buy',
        amount,
        quantity,
        pricePerUnit,
      );
      return;
    }

    // 2. Create New Investment
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    // Also create an initial "Buy" transaction for history for the new asset?
    // Current logic: Just creates summary.
    // Ideally: Create Investment + Create Transaction.
    // For MVP consistency with current logic: Just create Investment summary,
    // but maybe we SHOULD create a transaction too so history isn't empty?
    // Let's stick to current logic: Create Investment Object.

    final newInv = Investment(
      id: tempId,
      userId: '', // Set by backend/service context usually or ignored
      name: name,
      type: type,
      investedAmount: amount,
      currentAmount: amount, // Initially same
      quantity: quantity,
      lastUpdated: DateTime.now(),
    );

    _investments.insert(0, newInv);
    notifyListeners();

    if (_isHiveInitialized) {
      _investmentBox.put(tempId, newInv);
    }

    try {
      final result = await _appwriteService.createInvestment({
        'name': name,
        'type': type,
        'investedAmount': amount,
        'currentAmount': amount,
        'quantity': quantity,
      });

      if (result != null) {
        final realInv = Investment.fromJson(result);
        final index = _investments.indexWhere((i) => i.id == tempId);
        if (index != -1) {
          _investments[index] = realInv;
          if (_isHiveInitialized) {
            await _investmentBox.delete(tempId);
            await _investmentBox.put(realInv.id, realInv);
          }
          notifyListeners();
        }

        // Optional: Create initial transaction log for this new asset
        // So history shows "Initial Buy"
        /* 
        // Commented out to potentially fix duplicate quantity issue (1 becoming 2)
        // If the backend or logic was double counting this, removing this stops the second add.
        final pricePerUnit = quantity > 0 ? amount / quantity : 0.0;
        await addTransaction(
          realInv.id, // Use real ID
          'buy',
          amount,
          quantity,
          pricePerUnit,
          updateParent: false, // Fix: Don't update parent as it's already set
        );
        */
      }
    } catch (e) {
      print('Error adding investment: $e');
      // Revert? Or Keep offline? Keeping offline for now.
    }
  }

  Future<void> deleteInvestment(String id) async {
    _investments.removeWhere((i) => i.id == id);
    if (_isHiveInitialized) _investmentBox.delete(id);
    notifyListeners();

    await _appwriteService.deleteInvestment(id);
  }

  Future<void> updateCurrentValue(String id, double newValue) async {
    final index = _investments.indexWhere((i) => i.id == id);
    if (index == -1) return;

    final old = _investments[index];
    final updated = Investment(
      id: old.id,
      userId: old.userId,
      name: old.name,
      type: old.type,
      investedAmount: old.investedAmount,
      currentAmount: newValue,
      quantity: old.quantity,
      lastUpdated: DateTime.now(),
    );

    _investments[index] = updated;
    if (_isHiveInitialized) _investmentBox.put(id, updated);
    notifyListeners();

    await _appwriteService.updateInvestment(id, {
      'currentAmount': newValue,
      'lastUpdated': DateTime.now().toIso8601String(),
    });
  }

  // Record a Buy/Sell
  Future<void> addTransaction(
    String investmentId,
    String type,
    double amount,
    double quantity,
    double price, {
    bool updateParent = true,
  }) async {
    // 1. Validation for Sell
    if (type == 'sell') {
      final inv = _investments.firstWhere((i) => i.id == investmentId);
      if (quantity > inv.quantity) {
        throw Exception('Cannot sell more than you own!');
      }
    }

    // 2. Create Transaction
    final tempTx = InvestmentTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      investmentId: investmentId,
      userId: '',
      type: type,
      amount: amount,
      quantity: quantity,
      pricePerUnit: price,
      dateTime: DateTime.now(),
    );

    _transactions.insert(0, tempTx);
    _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // 3. Update Parent Investment (Locally)
    if (updateParent) {
      final invIndex = _investments.indexWhere((i) => i.id == investmentId);
      if (invIndex != -1) {
        final old = _investments[invIndex];
        double newInvested = old.investedAmount;
        double newCurrent = old.currentAmount;
        double newQty = old.quantity;

        if (type == 'buy') {
          newInvested += amount;
          // When buying, we assume current value increases by the buy amount immediately
          newCurrent += amount;
          newQty += quantity;
        } else {
          // Sell Logic
          if (old.quantity > 0) {
            final ratio = quantity / old.quantity;
            final portionInvested = old.investedAmount * ratio;
            newInvested -= portionInvested;
          }
          newCurrent -= amount;
          newQty -= quantity;
        }

        if (newQty < 0) newQty = 0;
        if (newInvested < 0) newInvested = 0;
        if (newCurrent < 0) newCurrent = 0;

        final updatedInv = Investment(
          id: old.id,
          userId: old.userId,
          name: old.name,
          type: old.type,
          investedAmount: newInvested,
          currentAmount: newCurrent,
          quantity: newQty,
          lastUpdated: DateTime.now(),
        );

        _investments[invIndex] = updatedInv;
        if (_isHiveInitialized) {
          _investmentBox.put(updatedInv.id, updatedInv);
          _transactionBox.put(tempTx.id, tempTx);
        }
        notifyListeners();
      }
    } else {
      // Just save the transaction locally
      if (_isHiveInitialized) {
        _transactionBox.put(tempTx.id, tempTx);
      }
      notifyListeners();
    }

    // API
    final txResult = await _appwriteService.createInvestmentTransaction({
      'investmentId': investmentId,
      'type': type,
      'amount': amount,
      'quantity': quantity,
      'pricePerUnit': price,
      'dateTime': DateTime.now().toIso8601String(),
    });

    if (txResult != null) {
      // Update Tx ID
      final realTx = InvestmentTransaction.fromJson(txResult);
      final txIndex = _transactions.indexWhere((t) => t.id == tempTx.id);
      if (txIndex != -1) {
        _transactions[txIndex] = realTx;
        if (_isHiveInitialized) {
          _transactionBox.delete(tempTx.id);
          _transactionBox.put(realTx.id, realTx);
        }
      }
    }

    // Update Investment on Server (Only if requested)
    if (updateParent) {
      // Need to fetch current state again? No, we updated local state.
      // But we need the values.
      final inv = _investments.firstWhere((i) => i.id == investmentId);
      await _appwriteService.updateInvestment(investmentId, {
        'investedAmount': inv.investedAmount,
        'currentAmount': inv.currentAmount,
        'quantity': inv.quantity,
      });
    }
  }

  Future<void> clearLocalData() async {
    if (_isHiveInitialized) {
      await _investmentBox.clear();
      await _transactionBox.clear();
    }
    _investments = [];
    _transactions = [];
    notifyListeners();
    await fetchInvestments();
  }

  Future<void> loadMoreInvestmentTransactions() async {
    if (!_hasMoreTransactions || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newData = await _appwriteService.getInvestmentTransactions(
        lastId: _lastTransactionId,
        limit: 25,
      );

      if (newData.isNotEmpty) {
        final newTransactions = newData
            .map((data) => InvestmentTransaction.fromJson(data))
            .toList();

        _transactions.addAll(newTransactions);
        _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _lastTransactionId = _transactions.last.id;
        _hasMoreTransactions = newData.length >= 25;

        if (_transactions.length <= 100 && _isHiveInitialized) {
          await _transactionBox.putAll({
            for (var t in newTransactions) t.id: t,
          });
        }
      } else {
        _hasMoreTransactions = false;
      }
    } catch (e) {
      print('Error loading more investment transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreInvestments() async {
    if (!_hasMoreInvestments || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newData = await _appwriteService.getInvestments(
        lastId: _investments.last.id,
        limit: 25,
      );

      if (newData.isNotEmpty) {
        final newInvestments = newData
            .map((d) => Investment.fromJson(d))
            .toList();
        _investments.addAll(newInvestments);
        _investments.sort(
          (a, b) => b.investedAmount.compareTo(a.investedAmount),
        );
        _hasMoreInvestments = newData.length >= 25;

        if (_isHiveInitialized) {
          await _investmentBox.putAll({for (var i in newInvestments) i.id: i});
        }
      } else {
        _hasMoreInvestments = false;
      }
    } catch (e) {
      print('Error loading more investments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
