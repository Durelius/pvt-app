import 'package:hive/hive.dart';
import 'address_entry.dart';

part 'address_group.g.dart';

@HiveType(typeId:2)
class AddressGroup {

  @HiveField(0)
  String name;

  @HiveField(1)
  List<AddressEntry> entries;

  AddressGroup({
    required this.name,
    required this.entries
  });
}