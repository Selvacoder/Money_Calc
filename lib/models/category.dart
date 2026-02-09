import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 2)
class Category {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String type; // 'expense' or 'income'

  @HiveField(4)
  final String icon;

  @HiveField(5)
  final int usageCount;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.icon,
    this.usageCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['\$id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'expense',
      icon: json['icon'] ?? '',
      usageCount: json['usageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'icon': icon,
      'usageCount': usageCount,
    };
  }
}
