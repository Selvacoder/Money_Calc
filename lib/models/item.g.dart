// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 3;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      id: fields[0] as String,
      userId: fields[1] as String,
      title: fields[2] as String,
      amount: fields[3] as double,
      isExpense: fields[4] as bool,
      categoryId: fields[5] as String,
      usageCount: (fields[6] as int?) ?? 0,
      frequency: fields[7] as String?,
      icon: fields[8] as String?,
      dueDay: fields[9] as int?,
      isVariable: fields[10] as bool?,
      order: (fields[11] as int?) ?? 9999,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.isExpense)
      ..writeByte(5)
      ..write(obj.categoryId)
      ..writeByte(6)
      ..write(obj.usageCount)
      ..writeByte(7)
      ..write(obj.frequency)
      ..writeByte(8)
      ..write(obj.icon)
      ..writeByte(9)
      ..write(obj.dueDay)
      ..writeByte(10)
      ..write(obj.isVariable)
      ..writeByte(11)
      ..write(obj.order);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
