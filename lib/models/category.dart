class Category {
  final String id;
  final String userId;
  final String name;
  final String type; // 'income' or 'expense'
  final String icon; // Icon code point or name
  final int usageCount;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.icon,
    required this.usageCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'type': type,
      'icon': icon,
      'usageCount': usageCount,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['\$id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? 'expense',
      icon: json['icon'] ?? '',
      usageCount: json['usageCount'] ?? 0,
    );
  }
}
