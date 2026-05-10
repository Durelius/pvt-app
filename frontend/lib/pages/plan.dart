import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:mitten/location_service/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../MapboxGeocodingService.dart';
import '../config.dart';

const Color kPurple = Color(0xFF63519F);

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
  final MapboxGeocodingService _geocoding = MapboxGeocodingService();

  List<Address> _suggestions = [];
  String _searchTerm = "";
  final List<Address> _items = [];
  int _searchVersion = 0;
  List<dynamic> _results = [];
  bool _isLoading = false;

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
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 72,
                ),
                child: _isLoading
                    ? _buildLoading()
                    : _results.isNotEmpty
                        ? _buildResults()
                        : _buildAddressList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasText = _controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: kPurple,
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                if (hasText) ...[
                  GestureDetector(
                    onTap: () => setState(() {
                      _controller.clear();
                      _searchTerm = '';
                      _suggestions = [];
                      _focusNode.unfocus();
                    }),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Add an address...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 15),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: _onTextChanged,
                  ),
                ),
                GestureDetector(
                  onTap: hasText
                      ? () => setState(() {
                            _controller.clear();
                            _searchTerm = '';
                            _suggestions = [];
                          })
                      : null,
                  child: Icon(
                    hasText ? Icons.close : Icons.mic,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: kPurple,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: kPurple.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.15), indent: 52),
                itemBuilder: (context, i) {
                  final parts = _suggestions[i].name.split(',');
                  final street = parts.first.trim();
                  final rest = parts.skip(1).join(',').trim();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, color: Colors.white70, size: 22),
                    title: Text(street,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                    subtitle: rest.isNotEmpty
                        ? Text(rest,
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)))
                        : null,
                    trailing: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 17),
                    ),
                    onTap: () => _selectSuggestion(_suggestions[i]),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAddressList() {
    return Column(
      children: [
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Text(
                    'Add at least two addresses\nto find a meeting point',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kPurple.withValues(alpha: 0.45), fontSize: 15, height: 1.6),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  itemCount: _items.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: kPurple.withValues(alpha: 0.15)),
                      ),
                      tileColor: kPurple.withValues(alpha: 0.06),
                      leading: const Icon(Icons.location_on, color: kPurple, size: 20),
                      title: Text(
                        _items[i].name,
                        style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      trailing: GestureDetector(
                        onTap: () => setState(() => _items.removeAt(i)),
                        child: Icon(Icons.remove_circle_outline, color: kPurple.withValues(alpha: 0.4), size: 20),
                      ),
                    ),
                  ),
                ),
        ),
        if (_items.length >= 2)
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _findMiddle,
                icon: const Icon(Icons.explore_outlined, color: Colors.white, size: 20),
                label: const Text(
                  'Find middle',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: kPurple, strokeWidth: 2.5),
          const SizedBox(height: 18),
          Text('Calculating...', style: TextStyle(color: kPurple.withValues(alpha: 0.7), fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              const Text(
                'Recommended places',
                style: TextStyle(color: kPurple, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _results = []),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: kPurple.withValues(alpha: 0.5), size: 16),
                    const SizedBox(width: 4),
                    Text('Back', style: TextStyle(color: kPurple.withValues(alpha: 0.5), fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _results.length,
                itemBuilder: (_, i) => _buildPlaceCard(_results[i]),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 72,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final name = place['displayName']['text'] as String;
    final address = place['formattedAddress'] as String;
    final rating = (place['rating'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => _showPlaceSheet(context, place),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: kPurple,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(address,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlaceSheet(BuildContext context, Map<String, dynamic> place) {
    final name = place['displayName']['text'] as String;
    final address = place['formattedAddress'] as String;
    final rating = (place['rating'] as num?)?.toDouble() ?? 0.0;
    final lat = (place['location']?['latitude'] as num?)?.toDouble();
    final lng = (place['location']?['longitude'] as num?)?.toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(name,
                style: const TextStyle(
                    color: kPurple, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                ...List.generate(5, (i) {
                  if (i < rating.floor()) {
                    return const Icon(Icons.star_rounded, color: Colors.amber, size: 20);
                  } else if (i < rating) {
                    return const Icon(Icons.star_half_rounded, color: Colors.amber, size: 20);
                  } else {
                    return const Icon(Icons.star_outline_rounded, color: Colors.amber, size: 20);
                  }
                }),
                const SizedBox(width: 8),
                Text(rating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, color: kPurple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(address,
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
                ),
              ],
            ),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Open in Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
