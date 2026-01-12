class Transaction {
  final String id;
  final String title;
  final double amount;
  final bool isExpense;
  final DateTime dateTime;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'isExpense': isExpense,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      isExpense: json['isExpense'],
      dateTime: DateTime.parse(json['dateTime']),
    );
  }
}
