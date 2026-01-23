import 'package:hive/hive.dart';

part 'investment.g.dart';

@HiveType(typeId: 5)
class Investment {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final double investedAmount;

  @HiveField(5)
  final double currentAmount;

  @HiveField(6)
  final double quantity;

  @HiveField(7)
  final DateTime lastUpdated;

  Investment({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.investedAmount,
    required this.currentAmount,
    required this.quantity,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type,
      'investedAmount': investedAmount,
      'currentAmount': currentAmount,
      'quantity': quantity,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory Investment.fromJson(Map<String, dynamic> json) {
    return Investment(
      id: json['\$id'] ?? json['id'],
      userId: json['userId'] ?? '',
      name: json['name'],
      type: json['type'],
      investedAmount: (json['investedAmount'] ?? 0).toDouble(),
      currentAmount: (json['currentAmount'] ?? 0).toDouble(),
      quantity: (json['quantity'] ?? 0).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}
