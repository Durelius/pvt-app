import 'package:flutter/material.dart';

import '../MapboxGeocodingService.dart';

import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/address_entry.dart';  

class PlanPage extends StatefulWidget{
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {

  final Debouncer debouncer = Debouncer();
  final TextEditingController controller = TextEditingController();

  //Mapbox API
  final MapboxGeocodingService geocoding = MapboxGeocodingService();
  List<String> suggestions = [];

  //addresses stored
  late Box<AddressEntry> entryBox;

  @override
  initState() {
    super.initState();
    entryBox = Hive.box<AddressEntry>('addressEntries');
  }

  void onTextChanged(String value) {
    debouncer.debounce(
      const Duration(milliseconds: 400),
      () async {
        print('Söker efter: $value');  // skrivs ut när debounce triggar

        if (value.trim().length < 4) {
          setState(() => suggestions = []);
          return;
        }
        final results = await geocoding.getSuggestions(value);
        print('Antal förslag: ${results.length}');  // hur många kom tillbaka?
        setState(() => suggestions = results);
      },
    );
  }

  void selectSuggestion(String address){
    final entry = AddressEntry(
      address: address,
      label: 'test',
    );

    entryBox.add(entry);

    setState(() {
      suggestions = [];
      controller.clear();
    });
  }

  void addItem(){
    if (controller.text.trim().isEmpty) return;
    final entry = AddressEntry(
      address: controller.text.trim(),
      label: 'test',
    );

    entryBox.add(entry);
    
    setState(() {
      controller.clear();
    });
  }
@override
  Widget build(BuildContext context){
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Address Please:', border: OutlineInputBorder()),
                    onChanged: onTextChanged,
                    onSubmitted: (_) => addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: addItem,
                ),
              ]),
              if (suggestions.isNotEmpty)       // <-- nu utanför Row
                Card(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) => ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(suggestions[index]),
                      onTap: () => selectSuggestion(suggestions[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: entryBox.listenable(),
            builder: (context, Box<AddressEntry> box, _) {
              return ListView.builder(
              itemCount: box.length,
              itemBuilder: (context, index) {
                final entry = box.getAt(index)!;
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(entry.address),
                );
              },
              );
            },
          ),
        ),
      ],
    );
  }
}