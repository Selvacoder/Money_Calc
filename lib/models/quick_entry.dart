class QuickEntry {
  final String title;
  final double amount;
  final bool isExpense;

  QuickEntry({
    required this.title,
    required this.amount,
    required this.isExpense,
  });

  Map<String, dynamic> toJson() {
    return {'title': title, 'amount': amount, 'isExpense': isExpense};
  }

  factory QuickEntry.fromJson(Map<String, dynamic> json) {
    return QuickEntry(
      title: json['title'],
      amount: json['amount'],
      isExpense: json['isExpense'],
    );
  }
}
