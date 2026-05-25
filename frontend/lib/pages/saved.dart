import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../main.dart' show kPurple;
import 'plan.dart' show decodeItems;
import '../MapboxGeocodingService.dart';

class SavedPage extends StatelessWidget {
  final void Function(List<Address>) onOpenPlan;
  const SavedPage({super.key, required this.onOpenPlan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text('Recent searches',
                    style: TextStyle(
                        color: kPurple,
                        fontSize: 22,
                        fontWeight: FontWeight.bold
                    )
                ),
              ),
              _RecentCarousel(onOpenPlan: onOpenPlan),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text('Saved groups',
                    style: TextStyle(
                        color: kPurple,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
              _SavedGroupsCarousel(onOpenPlan: onOpenPlan),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCarousel extends StatelessWidget {
  final void Function(List<Address>) onOpenPlan;
  const _RecentCarousel({required this.onOpenPlan});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('recentSearches').listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return _emptyLabel('No recent searches yet');
        }
        final keys = box.keys.toList().reversed.toList();
        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: keys.length,
            itemBuilder: (context, i) {
              final key = keys[i];
              final raw = box.get(key) as Map;
              final addressList = raw['addresses'] as List;
              final label = (raw['name'] as String).isNotEmpty
                  ? raw['name'] as String
                  : 'Search ${keys.length - i}';
              final addresses = decodeItems(addressList);
              return _SearchCard(
                isSavedGroup: false,
                label: label,
                addresses: addresses,
                onDelete: () => box.delete(key),
                onOpenPlan: onOpenPlan,
                onSaveAddresses: (updated) => box.put(key, {
                  'name': label,
                  'addresses': updated
                      .map((a) => {'name': a.name, 'lat': a.lat, 'lon': a.lon})
                      .toList(),
                }),
                onRename: (newName) => box.put(key, {
                  'name': newName,
                  'addresses': addresses
                      .map((a) => {'name': a.name, 'lat': a.lat, 'lon': a.lon})
                      .toList(),
                }),
              );
            },
          ),
        );
      },
    );
  }
}

class _SavedGroupsCarousel extends StatelessWidget {
  final void Function(List<Address>) onOpenPlan;
  const _SavedGroupsCarousel({required this.onOpenPlan});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('savedGroups').listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return _emptyLabel('No saved groups yet');
        }
        final keys = box.keys.toList();
        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: keys.length,
            itemBuilder: (context, i) {
              final key = keys[i];
              final data = box.get(key) as Map;
              final name = data['name'] as String;
              final addresses = decodeItems(data['addresses'] as List);
              return _SearchCard(
                isSavedGroup: true,
                label: name,
                addresses: addresses,
                onDelete: () => box.delete(key),
                onOpenPlan: onOpenPlan,
                onSaveAddresses: (updated) => box.put(key, {
                  'name': name,
                  'addresses': updated
                      .map((a) => {'name': a.name, 'lat': a.lat, 'lon': a.lon})
                      .toList(),
                }),
                onRename: (newName) => box.put(key, {   
                  'name': newName,
                  'addresses': addresses
                      .map((a) => {'name': a.name, 'lat': a.lat, 'lon': a.lon})
                      .toList(),
                }),
              );
            },
          ),
        );
      },
    );
  }
}

class _SearchCard extends StatelessWidget {
  final String label;
  final List<Address> addresses;
  final void Function(List<Address>) onOpenPlan;
  final VoidCallback onDelete;
  final void Function(List<Address>)? onSaveAddresses; 
  final void Function(String)? onRename;
  final bool isSavedGroup;

  const _SearchCard({
    required this.label,
    required this.addresses,
    required this.onOpenPlan,
    required this.onDelete,
    this.onSaveAddresses,
    this.onRename,
    required this.isSavedGroup,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGroupSheet(context),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            SizedBox(
                  height: 60,
                  child: isSavedGroup
                      ? Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: kPurple, width: 2),
                          ),
                          child: const Icon(Icons.groups, color: Colors.white, size: 18),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            ...List.generate(addresses.length.clamp(0, 3), (i) {
                              final offset =
                                  (i - (addresses.length.clamp(0, 3) - 1) / 2) * 18.0;
                              return Transform.translate(
                                offset: Offset(offset, 0),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kPurple, width: 2),
                                  ),
                                  child: const Icon(Icons.location_on,
                                      color: Colors.white, size: 18),
                                ),
                              );
                            }),
                          ],
                        ),
                ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text('${addresses.length} places',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showGroupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GroupSheet(
        addresses: addresses,
        onDelete: onDelete,
        onOpenPlan: onOpenPlan,
        onSaveAddresses: onSaveAddresses,
        isSavedGroup: isSavedGroup,
        onRename: onRename,
        currentName: label,
      ),
    );
  }
}

class _GroupSheet extends StatefulWidget {
  final List<Address> addresses;
  final VoidCallback onDelete;
  final void Function(List<Address>) onOpenPlan;
  final void Function(List<Address>)? onSaveAddresses;
  final bool isSavedGroup;
  final void Function(String)? onRename;
  final String currentName;

  const _GroupSheet({
    required this.addresses,
    required this.onDelete,
    required this.onOpenPlan,
    required this.isSavedGroup,
    this.onSaveAddresses,
    this.onRename,
    required this.currentName,
  });

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  late List<Address> _addresses;

  @override
  void initState() {
    super.initState();
    _addresses = List.from(widget.addresses);
  }

  void _renameGroup(BuildContext context) {
    final nameController = TextEditingController(text: widget.currentName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename group',
            style: TextStyle(color: kPurple, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) widget.onRename!(newName);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPurple),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _saveAsGroup(BuildContext context) {
    final box = Hive.box('savedGroups');
    final groupCount = box.length + 1;
    final nameController =
        TextEditingController(text: 'Group $groupCount');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save group',
            style: TextStyle(color: kPurple, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim().isEmpty
                  ? 'Group $groupCount'
                  : nameController.text.trim();
              box.add({
                'name': name,
                'addresses': _addresses
                    .map((a) =>
                        {'name': a.name, 'lat': a.lat, 'lon': a.lon})
                    .toList(),
              });
              Navigator.pop(context); // stäng dialog
              Navigator.pop(context); // stäng sheet
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPurple),
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Addresses',
                    style: TextStyle(
                        color: kPurple,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _renameGroup(context),
                    child: Icon(Icons.edit_outlined,
                        color: kPurple.withValues(alpha: 0.5), size: 30),
                  ),
                ],
            ),
            const SizedBox(height: 12),

            ..._addresses.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: kPurple.withValues(alpha: 0.15)),
                    ),
                    tileColor: kPurple.withValues(alpha: 0.06),
                    leading: const Icon(Icons.location_on,
                        color: kPurple, size: 20),
                    title: Text(a.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    trailing: GestureDetector(
                      onTap: () {
                        setState(() => _addresses.remove(a));
                        // Spara direkt om det är en grupp
                        if (widget.isSavedGroup) {
                          widget.onSaveAddresses!(_addresses);
                        }
                      },
                      child: Icon(Icons.remove_circle_outline,
                          color: kPurple.withValues(alpha: 0.4),
                          size: 20),
                    ),
                  ),
                )),

            const SizedBox(height: 20),

            if (_addresses.length >= 2)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenPlan(_addresses);
                },
                icon: const Icon(Icons.explore_outlined,
                    color: Colors.white, size: 20),
                label: const Text('Find middle',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),

            const SizedBox(height: 10),

            // Spara som grupp – visas bara för recent searches
            if (!widget.isSavedGroup)
              OutlinedButton.icon(
                onPressed: () => _saveAsGroup(context),
                icon: const Icon(Icons.bookmark_add_outlined,
                    color: kPurple, size: 18),
                label: const Text('Save as group',
                    style: TextStyle(color: kPurple)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kPurple),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                widget.onDelete();
                Navigator.pop(context);
              },
              child: Text(
                widget.isSavedGroup ? 'Delete group' : 'Delete search',
                style:
                    TextStyle(color: kPurple.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _emptyLabel(String text) => Padding(
  padding: const EdgeInsets.only(left: 20),
  child: Text(
    text,style: TextStyle(
          color: kPurple.withValues(alpha: 0.45), fontSize: 15
    )
  ),
);