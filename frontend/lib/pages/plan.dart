import 'package:flutter/material.dart';

import '../MapboxGeocodingService.dart';

import 'package:flutter_debouncer/flutter_debouncer.dart';


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
  final List<String> items = [];

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
    setState(() {
      items.add(address);
      suggestions = [];
      controller.clear();
    });
  }

  void addItem(){
    if (controller.text.trim().isEmpty) return;
    setState(() {
      items.add(controller.text.trim());
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
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(items[index]),
            ),
          ),
        ),
      ],
    );
  }
}