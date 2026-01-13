class Item {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final bool isExpense;
  final String categoryId;
  final int usageCount;
  final String? frequency; // 'daily' or 'monthly'

  Item({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.categoryId,
    this.usageCount = 0,
    this.frequency = 'daily',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'categoryId': categoryId,
      'usageCount': usageCount,
      'frequency': frequency,
    };
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['\$id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? 'Unknown',
      amount: (json['amount'] is int)
          ? (json['amount'] as int).toDouble()
          : (json['amount'] ?? 0.0),
      isExpense: json['isExpense'] ?? true,
      categoryId: json['categoryId'] ?? '',
      usageCount: json['usageCount'] ?? 0,
      frequency: json['frequency'] ?? 'daily',
    );
  }
}
