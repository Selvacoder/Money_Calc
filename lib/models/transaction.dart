class Transaction {
  final String id;
  final String title;
  final double amount;
  final bool isExpense;
  final DateTime dateTime;
  final String? categoryId;
  final String? itemId;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.dateTime,
    this.categoryId,
    this.itemId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'dateTime': dateTime.toIso8601String(),
      'categoryId': categoryId,
      'itemId': itemId,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown',
      amount: (json['amount'] is int)
          ? (json['amount'] as int).toDouble()
          : (json['amount'] ?? 0.0),
      isExpense: json['isExpense'] ?? true,
      dateTime: DateTime.parse(json['dateTime']),
      categoryId: json['categoryId'],
      itemId: json['itemId'],
    );
  }
}
