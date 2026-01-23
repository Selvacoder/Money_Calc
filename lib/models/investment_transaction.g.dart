// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'investment_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvestmentTransactionAdapter extends TypeAdapter<InvestmentTransaction> {
  @override
  final int typeId = 6;

  @override
  InvestmentTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvestmentTransaction(
      id: fields[0] as String,
      investmentId: fields[1] as String,
      userId: fields[2] as String,
      type: fields[3] as String,
      amount: fields[4] as double,
      pricePerUnit: fields[5] as double?,
      quantity: fields[6] as double?,
      dateTime: fields[7] as DateTime,
      note: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InvestmentTransaction obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.investmentId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.amount)
      ..writeByte(5)
      ..write(obj.pricePerUnit)
      ..writeByte(6)
      ..write(obj.quantity)
      ..writeByte(7)
      ..write(obj.dateTime)
      ..writeByte(8)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestmentTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
