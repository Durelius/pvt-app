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

  // Mapbox geocoding service för adressförslag
  final MapboxGeocodingService geocoding = MapboxGeocodingService();
  List<String> suggestions = [];
  String searchTerm = "";

  // Lista över tillagda adresser
  final List<String> items = [];

  // Lista över resultat från mittpunktsberäkning
  List<dynamic> _results = [];

  // Färgkonstanter
  static const Color purple = Color(0xFF63519F);
  static const Color yellow = Color(0xFFFFDC00);

  String _address = "";

  // Initierar sidan och hämtar adress för nuvarande position
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

  // Omvandlar koordinater till en läsbar adress och lägger till i items
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

  // Hämtar adressförslag från Mapbox när användaren skriver, med debounce
  void onTextChanged(String searchParam) {
    debouncer.debounce(const Duration(milliseconds: 400), () async {
      searchTerm = searchParam;
      print('Söker efter: $searchTerm');

      if (searchTerm.trim().length < 4) {
        setState(() => suggestions = []);
        return;
      }
      final results = await geocoding.getSuggestions(searchTerm);
      print('Antal förslag: ${results.length}');
      List<String> names = [];
      for (var i = 0; i < results.length; i++) {
        names.add(results[i].name);
      }
      setState(() => suggestions = names);
    });
  }

  // Lägger till ett valt förslag i items och rensar sökfältet
  void selectSuggestion(String address) {
    searchTerm = "";
    setState(() {
      items.add(address);
      suggestions = [];
      controller.clear();
    });
  }

  // Lägger till manuellt inskriven adress i items
  void addItem() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      items.add(controller.text.trim());
      controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: purple,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(0.0),
            child: Column(
              children: [
                // Sökfält för adress
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add an address...',
                            hintStyle: const TextStyle(color: Colors.white),
                            filled: true,
                            fillColor: purple,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: purple),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: purple),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(color: purple, width: 2),
                            ),
                          ),
                          onChanged: onTextChanged,
                          onSubmitted: (_) => addItem(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Visar "inga förslag" om sökning gav tomt resultat
                if (suggestions.isEmpty && searchTerm.isNotEmpty)
                  Card(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 1,
                      itemBuilder: (context, index) =>
                          const ListTile(title: Text("No suggestions found")),
                    ),
                  ),

                // Visar adressförslag från Mapbox
                if (suggestions.isNotEmpty)
                  Card(
                    color: purple,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                        ),
                        title: Text(
                          suggestions[index],
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: yellow),
                          onPressed: () => selectSuggestion(suggestions[index]),
                        ),
                        onTap: () => selectSuggestion(suggestions[index]),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Lista över tillagda adresser
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => Container(
                color: purple,
                child: ListTile(
                  title: Text(
                    items[index],
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: yellow),
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

          // Knapp för att hitta mittpunkten, visas när minst 2 adresser är tillagda
          if (items.length >= 2)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => findMiddle(items),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Find the middle',
                    style: TextStyle(color: purple),
                  ),
                ),
              ),
            ),

          // Karta som visar resultat
          if (_results.isNotEmpty) ...[
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
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(
                    markers: _results
                        .map((place) => Marker(
                              point: LatLng(
                                place['location']['latitude'],
                                place['location']['longitude'],
                              ),
                              width: 120,
                              height: 60,
                              child: Column(
                                children: [
                                  const Icon(Icons.place_rounded, color: purple),
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
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],

          // Lista över resultat med namn, rating och adress
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final place = _results[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 115, 102, 157),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place['displayName']['text'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: yellow, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${place['rating']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              place['formattedAddress'],
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Skickar adresserna till backend och hämtar platser nära mittpunkten
  Future<void> findMiddle(List<String> addresses) async {
    final addressJson = jsonEncode(
      addresses.map((a) {
        final parts = a.split(',');
        final zipAndCity = parts[1].trim().split(' ');
        final zip = "${zipAndCity[0]} ${zipAndCity[1]}".trim();
        final city = zipAndCity.sublist(2).join(' ').trim();
        return {"street": parts[0].trim(), "zip": zip, "city": city};
      }).toList(),
    );

    final uri =
        Uri.parse('http://localhost:8080/api/middle/v1/middleplaces').replace(
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