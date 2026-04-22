import 'dart:convert';
import 'package:flutter/material.dart';
import '../MapboxGeocodingService.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:http/http.dart' as http;


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
  List<Address> suggestions = [];
  

  //addresses stored
  final List<Address> addresses = [];

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

Future<void> findMiddle() async {
  if (addresses.isEmpty) return;

      final response = await http.post(
      Uri.parse('http://localhost:8080/api/mitten/v1/middleplaces'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'addresses': addresses}),
    );

  final result = jsonDecode(response.body);
  final lat = result['middle']['latitude'];
  final lng = result['middle']['longitude'];

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Middle: '),
      content: Text('Lat: $lat\nLng: $lng'),
    ),
  );
}
  void selectSuggestion(Address address){
    setState(() {
      addresses.add(address);
      suggestions = [];
      controller.clear();
    });
  }

  void addItem(){
    if (controller.text.trim().isEmpty) return;
    if (suggestions.isEmpty) return;
    setState(() {
      addresses.add(suggestions.first);
      suggestions = [];
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
                    decoration: const InputDecoration(hintText: 'Address:', border: OutlineInputBorder()),
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
                      title: Text(suggestions[index].name.toString()),
                      onTap: () => selectSuggestion(suggestions[index]),
                    ),
                  ),

                  
                ),
                ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: addresses.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(addresses[index].name.toString()),
            ),
          ),
        ),

        if (addresses.length >1)
                 ElevatedButton(
                  onPressed: findMiddle //todo: kalla pa find middle
                ,
                  child: const Text('Find the middle!')
          ),
          const SizedBox(width: 8),

          
      ],
    );
  }
}