import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:mitten/location_service/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../MapboxGeocodingService.dart';
import '../config.dart';
import 'home.dart';

class PlanPage extends StatefulWidget {
  final AppLocation? currentLocation;
  const PlanPage({super.key, this.currentLocation});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final Debouncer _debouncer = Debouncer();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Mapbox geocoding service för adressförslag
  final MapboxGeocodingService _geocoding = MapboxGeocodingService();
  List<Address> _suggestions = [];
  String _searchTerm = "";
  int _searchVersion = 0;

  // Lista över tillagda adresser
  final List<Address> _items = [];

  // Lista över resultat från mittpunktsberäkning
  List<dynamic> _results = [];
  bool _isLoading = false;

  // Färgkonstanter
  static const Color kPurple = Color(0xFF63519F);
  static const Color kYellow = Color(0xFFFFDC00);

  // Initierar sidan och hämtar adress för nuvarande position
  @override
  void initState() {
    super.initState();
    final lat = widget.currentLocation?.latitude ?? 0;
    final lng = widget.currentLocation?.longitude ?? 0;
    if (lat == 0 || lng == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveCurrentAddress(lat, lng));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Omvandlar koordinater till en läsbar adress och lägger till i items
  Future<void> _resolveCurrentAddress(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return;
      final p = placemarks.first;
      final label = [p.street, p.locality, p.country]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      setState(() => _items.add(Address(name: label, lat: lat, lon: lng)));
    } catch (_) {}
  }

  // Hämtar adressförslag från Mapbox när användaren skriver, med debounce
  void _onTextChanged(String value) {
    _debouncer.debounce(const Duration(milliseconds: 400), () async {
      _searchTerm = value;
      if (_searchTerm.trim().length < 4) {
        setState(() => _suggestions = []);
        return;
      }
      final version = ++_searchVersion;
      final results = await _geocoding.getSuggestions(_searchTerm);
      if (version == _searchVersion) {
        setState(() => _suggestions = results);
      }
    });
  }

  // Lägger till ett valt förslag i items och rensar sökfältet
  void _selectSuggestion(Address address) {
    _searchVersion++;
    _focusNode.unfocus();
    setState(() {
      _items.add(address);
      _suggestions = [];
      _searchTerm = '';
      _controller.clear();
    });
  }

  // Skickar koordinaterna till backend och hämtar platser nära mittpunkten
  Future<void> _findMiddle() async {
    setState(() { _isLoading = true; _results = []; });
    try {
      final pointsJson = jsonEncode(
        _items.map((a) => {'lat': a.lat, 'lon': a.lon}).toList(),
      );
      final uri = Uri.parse('$apiBase/middle/v1/middleplaces').replace(
        queryParameters: {'points': pointsJson, 'location_type': 'restaurant'},
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() => _results = jsonDecode(response.body));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not find results (${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error — is the server running?')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kPurple,
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
                          controller: _controller,
                          focusNode: _focusNode,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add an address...',
                            hintStyle: const TextStyle(color: Colors.white),
                            filled: true,
                            fillColor: kPurple,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: kPurple),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: kPurple),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: kPurple, width: 2),
                            ),
                          ),
                          onChanged: _onTextChanged,
                        ),
                      ),
                    ],
                  ),
                ),

                // Visar "inga förslag" om sökning gav tomt resultat
                if (_suggestions.isEmpty && _searchTerm.isNotEmpty)
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
                if (_suggestions.isNotEmpty)
                  Card(
                    color: kPurple,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: const Icon(Icons.location_on_rounded, color: Colors.white),
                        title: Text(
                          _suggestions[index].name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: kYellow),
                          onPressed: () => _selectSuggestion(_suggestions[index]),
                        ),
                        onTap: () => _selectSuggestion(_suggestions[index]),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Lista över tillagda adresser
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) => Container(
                color: kPurple,
                child: ListTile(
                  title: Text(
                    _items[index].name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: kYellow),
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
                ),
              ),
            ),
          ),

          // Knapp för att hitta mittpunkten, visas när minst 2 adresser är tillagda
          if (_items.length >= 2)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _findMiddle,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: kPurple, strokeWidth: 2),
                        )
                      : const Text('Find the middle', style: TextStyle(color: kPurple)),
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
                    (_results[0]['location']['latitude'] as num).toDouble(),
                    (_results[0]['location']['longitude'] as num).toDouble(),
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
                                (place['location']['latitude'] as num).toDouble(),
                                (place['location']['longitude'] as num).toDouble(),
                              ),
                              width: 120,
                              height: 60,
                              child: Column(
                                children: [
                                  const Icon(Icons.place_rounded, color: kPurple),
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
                final lat = (place['location']?['latitude'] as num?)?.toDouble();
                final lng = (place['location']?['longitude'] as num?)?.toDouble();
                return GestureDetector(
                  onTap: lat != null && lng != null
                      ? () {
                          final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      : null,
                  child: Container(
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
                            const Icon(Icons.star, color: kYellow, size: 16),
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
                            if (lat != null && lng != null)
                              const Icon(Icons.open_in_new, color: Colors.white54, size: 14),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}