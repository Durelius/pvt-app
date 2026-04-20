import 'package:hive/hive.dart';

part 'address_entry.g.dart';

@HiveType(typeId: 1)
class AddressEntry {
  @HiveField(0)
  String address;
  @HiveField(1)
  String label;
  AddressEntry({
    required this.address,
    required this.label,
  });
}