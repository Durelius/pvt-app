import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:mitten/location_service/location_service.dart';

import '../MapboxGeocodingService.dart';
import 'home.dart';

class PlanPage extends StatefulWidget {
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
  String searchTerm = "";

  //addresses stored
  final List<String> items = [];

  //list of results when searching for the middle
  List<dynamic> _results = [];

  String _address = "";

  @override
  void initState() {
    super.initState();
    double lat = widget.currentLocation?.latitude ?? 0;
    double lng = widget.currentLocation?.longitude ?? 0;
    if (lat == 0 || lng == 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _calculatedAddress(lat, lng);
      });
    });
  }

  //Hittar addressen baserat på koordinaterna
  Future<void> _calculatedAddress(double lat, double lng) async {
    try {
      debugPrint("Hämtar adress för koordinater: $lat, $lng");
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

  void onTextChanged(String searchParam) {
    debouncer.debounce(const Duration(milliseconds: 400), () async {
      searchTerm = searchParam;
      print('Söker efter: $searchTerm'); // skrivs ut när debounce triggar

      if (searchTerm.trim().length < 4) {
        setState(() => suggestions = []);
        return;
      }
      final results = await geocoding.getSuggestions(searchTerm);
      print('Antal förslag: ${results.length}'); // hur många kom tillbaka?
      List<String> names = [];
      for (var i = 0; i < results.length; i++) {
        names.add(results[i].name);
      }
      setState(() => suggestions = names);
    });
  }

  void selectSuggestion(String address) {
    searchTerm = "";
    setState(() {
      items.add(address);
      suggestions = [];
      controller.clear();
    });
  }

  void addItem() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      items.add(controller.text.trim());
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Address Please:',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: onTextChanged,
                      onSubmitted: (_) => addItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.add), onPressed: addItem),
                  ElevatedButton(
                    onPressed: () => findMiddle(items),
                    child: const Text('Find the middle'),
                  ),
                ],
              ),

              if (suggestions.isEmpty &&
                  searchTerm.isNotEmpty)
                Card(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 1,
                    itemBuilder: (context, index) =>
                        ListTile(title: Text("No suggestions found")),
                  ),
                ),

              if (suggestions.isNotEmpty)
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
              color: index % 2 == 0 ? Colors.lightGreen : Colors.transparent,
              child: ListTile(
                title: Text(items[index]),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    setState(() {
                      items.removeAt(index);
                    });
                  },
                ),
              ),
            ),
          ),
        ),
        if (_results.isNotEmpty) ... [
          SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  _results[0]['location']['latitude'],
                  _results[0]['location']['longitude'],
                ),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: _results.map((place) => Marker(
                    point: LatLng(
                      place['location']['latitude'],
                      place['location']['longitude'],
                    ),
                    width: 120,
                    height: 60,
                    child: Column(
                      children: [
                        const Icon(Icons.place, color: Colors.purple),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            place['displayName']['text'],
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final place = _results[index];
                return ListTile(
                  leading: const Icon(Icons.restaurant),
                  title: Text(place['displayName']['text']),
                  subtitle: Text(place['formattedAddress']),
                  trailing: Text('⭐ ${place['rating']}'),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> findMiddle(List<String> addresses) async {
    final addressJson = jsonEncode(
      addresses.map((a) {
        final parts = a.split(',');
        final zipAndCity = parts[1].trim().split(
          ' ',
        ); // postnummer och postort hamnar på samma line
        final zip = "${zipAndCity[0]} ${zipAndCity[1]}"
            .trim(); // "xxx xx" för postnummer
        final city = zipAndCity.sublist(2).join(' ').trim(); // "postort"
        return {"street": parts[0].trim(), "zip": zip, "city": city};
      }).toList(),
    );

    final uri = Uri.parse('http://localhost:8080/api/middle/v1/middleplaces')
        .replace(
          queryParameters: {
            'addresses': addressJson,
            'location_type': 'restaurant',
          },
        );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      print(response.body);
      final data = jsonDecode(response.body);
      setState(() {
        _results = data;
      });
    } else {
      print('Fel: ${response.statusCode}');
    }
  }
}

