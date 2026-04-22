// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_group.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AddressGroupAdapter extends TypeAdapter<AddressGroup> {
  @override
  final int typeId = 2;

  @override
  AddressGroup read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AddressGroup(
      name: fields[0] as String,
      entries: (fields[1] as List).cast<AddressEntry>(),
    );
  }

  @override
  void write(BinaryWriter writer, AddressGroup obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.entries);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
