import 'package:hive/hive.dart';

part 'ledger_transaction.g.dart';

@HiveType(typeId: 4)
class LedgerTransaction {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String senderId;

  @HiveField(2)
  final String senderName;

  @HiveField(3)
  final String senderPhone;

  @HiveField(4)
  final String receiverName;

  @HiveField(5)
  final String? receiverPhone;

  @HiveField(6)
  final double amount;

  @HiveField(7)
  final String description;

  @HiveField(8)
  final DateTime dateTime;

  @HiveField(9)
  final String status; // 'pending', 'confirmed', 'rejected'

  @HiveField(10)
  final String? receiverId;

  @HiveField(11)
  final String creatorId;

  String get ledgerId => id; // Alias if needed

  LedgerTransaction({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderPhone,
    required this.receiverName,
    this.receiverPhone,
    required this.amount,
    required this.description,
    required this.dateTime,
    this.status = 'confirmed',
    this.receiverId,
    this.creatorId = '',
  });

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) {
    // Robust date parsing
    String? dateStr = json['dateTime'] ?? json['date'] ?? json['\$createdAt'];
    DateTime parsedDate;
    if (dateStr != null) {
      try {
        parsedDate = DateTime.parse(dateStr).toLocal();
      } catch (e) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return LedgerTransaction(
      id: json['\$id'] ?? json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderPhone: json['senderPhone'] ?? '',
      receiverName: json['receiverName'] ?? '',
      receiverPhone: json['receiverPhone'],
      amount: (json['amount'] ?? 0.0).toDouble(),
      description: json['description'] ?? '',
      dateTime: parsedDate,
      status: json['status'] ?? 'confirmed',
      receiverId: json['receiverId'],
      creatorId: json['creatorId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'amount': amount,
      'description': description,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
      'receiverId': receiverId,
      'creatorId': creatorId,
    };
  }

  LedgerTransaction copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? senderPhone,
    String? receiverName,
    String? receiverPhone,
    double? amount,
    String? description,
    DateTime? dateTime,
    String? status,
    String? receiverId,
    String? creatorId,
  }) {
    return LedgerTransaction(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      status: status ?? this.status,
      receiverId: receiverId ?? this.receiverId,
      creatorId: creatorId ?? this.creatorId,
    );
  }
}
