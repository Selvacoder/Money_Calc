import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/quick_entry.dart';

class StorageService {
  static const String _transactionsKey = 'transactions';
  static const String _quickEntriesKey = 'quick_entries';

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(_transactionsKey, jsonEncode(jsonList));
  }

  Future<List<Transaction>> loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_transactionsKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Transaction.fromJson(json)).toList();
  }

  Future<void> saveQuickEntries(List<QuickEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = entries.map((e) => e.toJson()).toList();
    await prefs.setString(_quickEntriesKey, jsonEncode(jsonList));
  }

  Future<List<QuickEntry>> loadQuickEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_quickEntriesKey);
    if (jsonString == null) {
      // Return default quick entries
      return [
        QuickEntry(title: 'Tea', amount: 20.00, isExpense: true),
        QuickEntry(title: 'Salary', amount: 50000.00, isExpense: false),
        QuickEntry(title: 'Petrol', amount: 500.00, isExpense: true),
      ];
    }

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => QuickEntry.fromJson(json)).toList();
  }
}
