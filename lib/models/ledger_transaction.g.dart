// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LedgerTransactionAdapter extends TypeAdapter<LedgerTransaction> {
  @override
  final int typeId = 4;

  @override
  LedgerTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LedgerTransaction(
      id: fields[0] as String,
      senderId: fields[1] as String,
      senderName: fields[2] as String,
      senderPhone: fields[3] as String,
      receiverName: fields[4] as String,
      receiverPhone: fields[5] as String?,
      amount: fields[6] as double,
      description: fields[7] as String,
      dateTime: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LedgerTransaction obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.senderId)
      ..writeByte(2)
      ..write(obj.senderName)
      ..writeByte(3)
      ..write(obj.senderPhone)
      ..writeByte(4)
      ..write(obj.receiverName)
      ..writeByte(5)
      ..write(obj.receiverPhone)
      ..writeByte(6)
      ..write(obj.amount)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.dateTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
