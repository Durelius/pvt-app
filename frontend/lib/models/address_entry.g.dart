// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AddressEntryAdapter extends TypeAdapter<AddressEntry> {
  @override
  final int typeId = 1;

  @override
  AddressEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AddressEntry(
      address: fields[0] as String,
      label: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AddressEntry obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.address)
      ..writeByte(1)
      ..write(obj.label);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
