import 'package:hive/hive.dart';

part 'item.g.dart';

@HiveType(typeId: 3)
class Item {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final bool isExpense;

  @HiveField(5)
  final String categoryId;

  @HiveField(6, defaultValue: 0)
  final int usageCount;

  @HiveField(7)
  final String? frequency;

  @HiveField(8)
  final String? icon;

  @HiveField(9)
  final int? dueDay;

  @HiveField(10)
  final bool? isVariable;

  @HiveField(11, defaultValue: 9999)
  final int order;

  String get name => title; // Alias match

  Item({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.categoryId,
    this.usageCount = 0,
    this.frequency,
    this.icon,
    this.dueDay,
    this.isVariable,
    this.order = 9999,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['\$id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      isExpense: json['isExpense'] ?? true,
      categoryId: json['categoryId'] ?? '',
      usageCount: json['usageCount'] ?? 0,
      frequency: json['frequency']?.toString().trim().toLowerCase(),
      icon: json['icon'],
      dueDay: json['dueDay'],
      isVariable:
          json['isVariable'] ??
          (json['frequency']?.toString().trim().toLowerCase() == 'variable'),
      order: json['order'] ?? 9999,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'categoryId': categoryId,
      'usageCount': usageCount,
      'frequency': frequency,
      'icon': icon,
      'dueDay': dueDay,
      'isVariable': isVariable,
    };
  }
}
