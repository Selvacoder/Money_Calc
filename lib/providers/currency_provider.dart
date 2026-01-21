import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyProvider extends ChangeNotifier {
  String _currencySymbol = '₹';
  String _currencyCode = 'INR';

  String get currencySymbol => _currencySymbol;
  String get currencyCode => _currencyCode;

  static const List<Map<String, String>> currencies = [
    {'code': 'USD', 'symbol': '\$'},
    {'code': 'EUR', 'symbol': '€'},
    {'code': 'GBP', 'symbol': '£'},
    {'code': 'INR', 'symbol': '₹'},
    {'code': 'JPY', 'symbol': '¥'},
    {'code': 'CAD', 'symbol': 'C\$'},
    {'code': 'AUD', 'symbol': 'A\$'},
    {'code': 'CNY', 'symbol': '¥'},
    {'code': 'CHF', 'symbol': 'Fr'},
    {'code': 'HKD', 'symbol': 'HK\$'},
  ];

  CurrencyProvider() {
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString('currency_symbol') ?? '₹';
    _currencyCode = prefs.getString('currency_code') ?? 'INR';
    notifyListeners();
  }

  Future<void> setCurrency(String code, String symbol) async {
    _currencyCode = code;
    _currencySymbol = symbol;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_code', code);
    await prefs.setString('currency_symbol', symbol);
  }
}
