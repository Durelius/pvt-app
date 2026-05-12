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
  final MapController _mapController = MapController();

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
  int _selectedIndex = 0;

  void _selectPlace(int index) {
    setState(() => _selectedIndex = index);
    // Flytta kartan till den valda platsen
    _mapController.move(
      LatLng(
        (_results[index]['location']['latitude'] as num).toDouble(),
        (_results[index]['location']['longitude'] as num).toDouble(),
      ),
      14,
    );
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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

          // Knapp för att hitta mittpunkten, visas när minst 2 adresser är tillagda
          if (_items.length >= 2)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
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
          ),
          // Karta som visar resultat
if (_results.isNotEmpty) ...[
  Expanded(
    child: Stack(
      children: [
        // Kartan tar upp hela ytan
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(
              (_results[0]['location']['latitude'] as num).toDouble(),
              (_results[0]['location']['longitude'] as num).toDouble(),
            ),
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken',
              userAgentPackageName: 'com.example.app',
            ),
            MarkerLayer(
              markers: _results.asMap().entries.map((entry) {
                final i = entry.key;
                final place = entry.value;
                final isSelected = _selectedIndex == i;
                return Marker(
                  point: LatLng(
                    (place['location']['latitude'] as num).toDouble(),
                    (place['location']['longitude'] as num).toDouble(),
                  ),
                  width: 140,
                  height: 70,
                  child: GestureDetector(
                    onTap: () => _selectPlace(i),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isSelected ? kYellow : kPurple,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.restaurant,
                            color: isSelected ? kPurple : Colors.white,
                            size: 16),
                        ),
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
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Bottom sheet ovanpå kartan
        DraggableScrollableSheet(
          initialChildSize: 0.40,
          minChildSize: 0.18,
          maxChildSize: 0.75,
          builder: (context, scrollController) {
            final place = _results[_selectedIndex];
            final lat = (place['location']['latitude'] as num).toDouble();
            final lng = (place['location']['longitude'] as num).toDouble();
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black26)],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  // Handtag
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Snabbval — lista med alla resultat
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ChoiceChip(
                        label: Text(_results[i]['displayName']['text']),
                        selected: _selectedIndex == i,
                        onSelected: (_) => _selectPlace(i),
                        selectedColor: kPurple,
                        labelStyle: TextStyle(
                          color: _selectedIndex == i ? Colors.white : kPurple,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Namn och kategori
                  Text(
                    place['displayName']['text'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),

                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: kYellow, size: 18),
                      const SizedBox(width: 4),
                      Text('${place['rating']}',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      Text('(${place['userRatingCount']} recensioner)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 24),

                  // Adress
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, color: kPurple, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(place['formattedAddress'],
                        style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Knappar
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => launchUrl(Uri.parse(
                            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')),
                          icon: const Icon(Icons.directions),
                          label: const Text('Vägbeskrivning'),
                          style: FilledButton.styleFrom(backgroundColor: kPurple),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$lat,$lng')),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Maps'),
                        style: OutlinedButton.styleFrom(foregroundColor: kPurple),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  ),
],
        ],
      ),
    );
  }
}