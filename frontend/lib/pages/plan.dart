import 'package:flutter/material.dart';
import 'package:mitten/location_service/location_service.dart';

import '../MapboxGeocodingService.dart';

import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:geocoding/geocoding.dart';

class PlanPage extends StatefulWidget{
  final AppLocation? currentLocation;
  const PlanPage({super.key, this.currentLocation});

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

  String _address = "Hämtar adress...";
  double lat = 59.37593262836998; // Stockholm
  double lng = 17.93474721023436;

  @override
  void initState(){
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
          _calculatedAddress();
      });
    });
  }
  //Hittar addressen baserat på koordinaterna
  Future<void> _calculatedAddress() async{
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      
    if (placemarks.isEmpty) {
      return;
    }
      Placemark place = placemarks.first;
      setState(() {
        _address = "${place.street}, ${place.country}";
        items.add(_address);
      });
    } catch (e) {
      return;
    }
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
            itemBuilder: (context, index) => Container(
              color: index == 0 ? Colors.lightGreen : Colors.transparent, // <-- grön bakgrund för första item
              child: ListTile(
                title: Text(items[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}