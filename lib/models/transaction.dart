import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 1)
class Transaction {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final bool isExpense;

  @HiveField(4)
  final DateTime dateTime;

  @HiveField(5)
  final String? categoryId;

  @HiveField(6)
  final String? itemId;

  @HiveField(7)
  final String? ledgerId;

  @HiveField(8)
  final String? paymentMethod;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    this.isExpense = true,
    required this.dateTime,
    this.categoryId,
    this.itemId,
    this.ledgerId,
    this.paymentMethod,
  });

  String get description => title;
  TransactionType get type =>
      isExpense ? TransactionType.expense : TransactionType.income;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['\$id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      isExpense: json['isExpense'] ?? true,
      dateTime: DateTime.parse(
        json['dateTime'] ?? DateTime.now().toIso8601String(),
      ),
      categoryId: json['categoryId'],
      itemId: json['itemId'],
      ledgerId: json['ledgerId'],
      paymentMethod: json['paymentMethod'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'dateTime': dateTime.toIso8601String(),
      'categoryId': categoryId,
      'itemId': itemId,
      'ledgerId': ledgerId,
      'paymentMethod': paymentMethod,
    };
  }
}

enum TransactionType { expense, income }
