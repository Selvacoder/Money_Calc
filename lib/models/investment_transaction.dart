import 'package:hive/hive.dart';

part 'investment_transaction.g.dart';

@HiveType(typeId: 6)
class InvestmentTransaction {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String investmentId;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final String type; // 'buy' or 'sell'

  @HiveField(4)
  final double amount;

  @HiveField(5)
  final double? pricePerUnit;

  @HiveField(6)
  final double? quantity;

  @HiveField(7)
  final DateTime dateTime;

  @HiveField(8)
  final String? note;

  InvestmentTransaction({
    required this.id,
    required this.investmentId,
    required this.userId,
    required this.type,
    required this.amount,
    this.pricePerUnit,
    this.quantity,
    required this.dateTime,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'investmentId': investmentId,
      'userId': userId,
      'type': type,
      'amount': amount,
      'pricePerUnit': pricePerUnit,
      'quantity': quantity,
      'dateTime': dateTime.toIso8601String(),
      'note': note,
    };
  }

  factory InvestmentTransaction.fromJson(Map<String, dynamic> json) {
    return InvestmentTransaction(
      id: json['\$id'] ?? json['id'],
      investmentId: json['investmentId'] ?? '',
      userId: json['userId'] ?? '',
      type: json['type'] ?? 'buy',
      amount: (json['amount'] ?? 0).toDouble(),
      pricePerUnit: (json['pricePerUnit'])?.toDouble(),
      quantity: (json['quantity'])?.toDouble(),
      dateTime: DateTime.parse(json['dateTime']),
      note: json['note'],
    );
  }
}
