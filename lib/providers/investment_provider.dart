import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/investment.dart';
import '../models/investment_transaction.dart';
import '../services/appwrite_service.dart';

class InvestmentProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();

  List<Investment> _investments = [];
  List<InvestmentTransaction> _transactions = [];
  bool _isLoading = false;

  List<Investment> get investments => _investments;
  List<InvestmentTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

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
        await _investmentBox.clear();
        await _investmentBox.putAll({for (var i in _investments) i.id: i});
      }

      final txData = await _appwriteService.getInvestmentTransactions();
      final networkTx = txData
          .map((d) => InvestmentTransaction.fromJson(d))
          .toList();

      if (networkTx.isNotEmpty) {
        _transactions = networkTx;
        _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        await _transactionBox.clear();
        await _transactionBox.putAll({for (var t in _transactions) t.id: t});
      }
    } catch (e) {
      print('Error fetching investments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addInvestment(String name, String type, double amount) async {
    // Optimistic Update
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    // Default initial investment creates a "Buy" transaction implicitly?
    // Or we stick to explicitly creating it.
    // Let's create the Investment object first.

    final newInv = Investment(
      id: tempId,
      userId: '', // Set by backend/service context usually or ignored
      name: name,
      type: type,
      investedAmount: amount,
      currentAmount: amount, // Initially same
      quantity: 0, // Logic specific to type (e.g. Gold grams), optional for MVP
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
    double price,
  ) async {
    // 1. Create Transaction
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

    // 2. Update Parent Investment
    final invIndex = _investments.indexWhere((i) => i.id == investmentId);
    if (invIndex != -1) {
      final old = _investments[invIndex];
      double newInvested = old.investedAmount;
      double newCurrent = old.currentAmount;
      double newQty = old.quantity; // Assuming quantity is tracked

      if (type == 'buy') {
        newInvested += amount;
        newCurrent += amount; // Assuming bought at current price
        newQty += quantity;
      } else {
        // Sell
        // Invested amount logic on sell is tricky. usually "fifo" or "average cost".
        // Simple MVP: Reduce invested amount proportionally? Or just log it?
        // Let's say we sell 50% of holdings. We reduce invested capital by 50%?
        // Or we just reduce current amount (value withdrawn).
        // Let's do: Reduce quantity and current amount.
        // Don't reduce 'investedAmount' if we want to track 'Net Investment'.
        // Actually, Selling = Booking Profit/Loss.
        // Let's keep it simple: Realized P/L is tricky.
        // Let's just update current value and quantity.
        newCurrent -= amount;
        newQty -= quantity;
      }

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

      // Update Investment on Server
      await _appwriteService.updateInvestment(investmentId, {
        'investedAmount': newInvested,
        'currentAmount': newCurrent,
        'quantity': newQty,
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
}
