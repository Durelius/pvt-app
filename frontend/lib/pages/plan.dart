import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:mitten/location_service/location_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../MapboxGeocodingService.dart';
import '../config.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import 'home.dart';

const Color kPurple = Color(0xFF63519F);

final Box recentSearches = Hive.box('recentSearches');
final homeAddressBox = Hive.box('homeAddress');

class PlanPage extends StatefulWidget {
  final AppLocation? currentLocation;
  final List<Address>? prefilledAddresses;
  const PlanPage({super.key, this.currentLocation, this.prefilledAddresses});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final Debouncer _debouncer = Debouncer();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final MapboxGeocodingService _geocoding = MapboxGeocodingService();
  final MapController _mapController = MapController();

  bool _hasCurrentLocation = false;
  bool _hasMyAddress = false;
  final String _homeAddressName = 'Saved home address';
  final homeAddressBox = Hive.box('homeAddress');

  List<Address> _suggestions = [];
  List<FriendUser> _friendSuggestions = [];
  List<FriendUser> _friends = [];
  String _searchTerm = "";
  final List<Address> _items = [];
  int _searchVersion = 0;
  List<dynamic> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.prefilledAddresses != null) {
      _items.addAll(widget.prefilledAddresses!);
    }

    if (AuthService.instance.isLoggedIn) _loadFriends();

    /*final lat = widget.currentLocation?.latitude ?? 0;
    final lng = widget.currentLocation?.longitude ?? 0;
    if (lat == 0 || lng == 0) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _resolveCurrentAddress(lat, lng),
    );*/
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
      final label = [
        p.street,
        p.locality,
        p.country,
      ].where((s) => s != null && s.isNotEmpty).join(', ');
      setState(() => _items.add(Address(name: label, lat: lat, lon: lng)));
    } catch (_) {}
  }

  Future<void> _loadFriends() async {
    final friends = await FriendsService.getFriends();
    if (mounted) setState(() => _friends = friends);
  }

  void _onTextChanged(String value) {
    _debouncer.debounce(const Duration(milliseconds: 400), () async {
      _searchTerm = value;
      final term = _searchTerm.trim();
      if (term.length < 2) {
        setState(() { _suggestions = []; _friendSuggestions = []; });
        return;
      }

      final matchingFriends = _friends
          .where((f) => f.name.toLowerCase().contains(term.toLowerCase()))
          .toList();

      if (term.length < 4) {
        setState(() { _suggestions = []; _friendSuggestions = matchingFriends; });
        return;
      }

      final version = ++_searchVersion;
      final results = await _geocoding.getSuggestions(_searchTerm);
      if (version == _searchVersion) {
        setState(() {
          _suggestions = results;
          _friendSuggestions = matchingFriends;
        });
      }
    });
  }

  void _selectFriend(FriendUser friend) {
    if (!friend.hasHomeAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${friend.name} hasn't set a home address yet")),
      );
      return;
    }
    _selectSuggestion(Address(
      name: "${friend.name}'s home",
      lat: friend.homeAddressLat,
      lon: friend.homeAddressLon,
    ));
  }

  void _selectSuggestion(Address address) {
    _searchVersion++;
    _focusNode.unfocus();
    setState(() {
      _items.add(address);
      _suggestions = [];
      _friendSuggestions = [];
      _searchTerm = '';
      _controller.clear();
    });
  }

  Future<void> _findMiddle() async {
    setState(() {
      _isLoading = true;
      _results = [];
    });
    try {
      final pointsJson = jsonEncode(
        _items.map((a) => {'lat': a.lat, 'lon': a.lon}).toList(),
      );
      final uri = Uri.parse('$apiBase/middle/v1/middleplaces').replace(
        queryParameters: {'points': pointsJson, 'location_type': 'cafe'},
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() => _results = jsonDecode(response.body));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not find results (${response.statusCode})'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error — is the server running?'),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
    final encodedItems = encodeItems(_items);
    recentSearches.add({'name': '', 'addresses': encodedItems});

    // Max 10 recent searches, ta bort äldsta om det är fler
    while (recentSearches.length > 10) {
      recentSearches.deleteAt(0);
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
                      _friendSuggestions = [];
                      _focusNode.unfocus();
                    }),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
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
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 15,
                      ),
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
                          _friendSuggestions = [];
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
          if (_friendSuggestions.isNotEmpty || _suggestions.isNotEmpty)
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
                itemCount: _friendSuggestions.length + _suggestions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                  indent: 52,
                ),
                itemBuilder: (context, i) {
                  if (i < _friendSuggestions.length) {
                    final friend = _friendSuggestions[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, color: Colors.white70, size: 22),
                      title: Text(
                        friend.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                      ),
                      subtitle: friend.hasHomeAddress
                          ? Text(
                              friend.homeAddressName,
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)),
                            )
                          : Text(
                              'No home address set',
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                            ),
                      trailing: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 17),
                      ),
                      onTap: () => _selectFriend(friend),
                    );
                  }
                  final idx = i - _friendSuggestions.length;
                  final parts = _suggestions[idx].name.split(',');
                  final street = parts.first.trim();
                  final rest = parts.skip(1).join(',').trim();
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, color: Colors.white70, size: 22),
                    title: Text(
                      street,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                    ),
                    subtitle: rest.isNotEmpty
                        ? Text(rest, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)))
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
                    onTap: () => _selectSuggestion(_suggestions[idx]),
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _hasCurrentLocation
                      ? null
                      : () {
                          final lat = widget.currentLocation?.latitude;
                          final lng = widget.currentLocation?.longitude;
                          if (lat != null && lng != null) {
                            setState(() => _hasCurrentLocation = true);
                            _resolveCurrentAddress(lat, lng);
                          }
                        },
                  icon: const Icon(Icons.my_location, size: 16, color: kPurple),
                  label: const Text(
                    'Use current location',
                    style: TextStyle(color: kPurple, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kPurple),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _hasMyAddress
                      ? null
                      : () {
                          final raw = homeAddressBox.get('homeAddress');
                          if (raw == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No home address saved in profile')),
                            );
                            return;
                          }
                          try {
                            final data = jsonDecode(raw as String) as Map<String, dynamic>;
                            setState(() {
                              _hasMyAddress = true;
                              _items.add(Address(
                                name: data['name'] as String,
                                lat: (data['lat'] as num).toDouble(),
                                lon: (data['lon'] as num).toDouble(),
                              ));
                            });
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No home address saved in profile')),
                            );
                          }
                        },
                  icon: const Icon(Icons.home_outlined, size: 16, color: kPurple),
                  label: const Text(
                    'Use my address',
                    style: TextStyle(color: kPurple, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kPurple),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
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
                    style: TextStyle(
                      color: kPurple.withValues(alpha: 0.45),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  itemCount: _items.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: kPurple.withValues(alpha: 0.15),
                        ),
                      ),
                      tileColor: kPurple.withValues(alpha: 0.06),
                      leading: const Icon(
                        Icons.location_on,
                        color: kPurple,
                        size: 20,
                      ),
                      title: Text(
                        _items[i].name,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: GestureDetector(
                        onTap: () => setState(() {
                          final removed = _items[i];
                          if (removed.name == _homeAddressName) {
                            _hasMyAddress = false;
                          }
                          final lat = widget.currentLocation?.latitude;
                          final lng = widget.currentLocation?.longitude;
                          if (removed.lat == lat && removed.lon == lng) {
                            _hasCurrentLocation = false;
                          }
                          _items.removeAt(i);
                        }),

                        child: Icon(
                          Icons.remove_circle_outline,
                          color: kPurple.withValues(alpha: 0.4),
                          size: 20,
                        ),
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
                icon: const Icon(
                  Icons.explore_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Find middle',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
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
          Text(
            'Calculating...',
            style: TextStyle(
              color: kPurple.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  double? _lat(Map<String, dynamic> place) =>
      (place['location']?['latitude'] as num?)?.toDouble();
  double? _lng(Map<String, dynamic> place) =>
      (place['location']?['longitude'] as num?)?.toDouble();

  Widget _buildResults() {
    final firstWithLocation = _results.cast<Map<String, dynamic>>().firstWhere(
      (p) => _lat(p) != null && _lng(p) != null,
      orElse: () => {},
    );
    final centerLat = _lat(firstWithLocation) ?? 59.3293;
    final centerLng = _lng(firstWithLocation) ?? 18.0686;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
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
                  .cast<Map<String, dynamic>>()
                  .where((p) => _lat(p) != null && _lng(p) != null)
                  .map(
                    (place) => Marker(
                      point: LatLng(_lat(place)!, _lng(place)!),
                      width: 120,
                      height: 60,
                      child: GestureDetector(
                        onTap: () => _showPlaceSheet(context, place),
                        child: Column(
                          children: [
                            const Icon(Icons.place, color: kPurple, size: 28),
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Text(
                                place['displayName']['text'],
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),

        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.15,
          maxChildSize: 1.0,
          expand: true,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      children: [
                        const Text(
                          'Recommended places',
                          style: TextStyle(
                            color: kPurple,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _results = []),
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_back,
                                color: kPurple.withValues(alpha: 0.5),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Back',
                                style: TextStyle(
                                  color: kPurple.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
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
                          controller: scrollController,
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
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final name = place['displayName']['text'] as String;
    final address = place['formattedAddress'] as String;
    // Foursquare rating is 0–10; divide by 2 for 5-star display
    final rating = ((place['rating'] as num?)?.toDouble() ?? 0.0) / 2.0;
    final openNow = place['openNow'] as bool?;
    final cuisine = (place['cuisine'] as String?)?.split(';').first;
    final priceLevel = place['priceLevel'] as int? ?? 0;

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
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    rating > 0 ? rating.toStringAsFixed(1) : '–',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (openNow != null) _openBadge(openNow),
                  if (cuisine != null && cuisine.isNotEmpty) ...[
                    if (openNow != null) const SizedBox(width: 6),
                    _cuisineChip(cuisine),
                  ],
                  if (priceLevel > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '\$' * priceLevel,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.white54,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _openBadge(bool isOpen) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isOpen ? Colors.green.shade400 : Colors.red.shade300,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isOpen ? 'Open' : 'Closed',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  Widget _cuisineChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      );

  // "View on map" moves camera; "Get directions" opens Maps
  void _showPlaceSheet(BuildContext context, Map<String, dynamic> place) {
    final name = place['displayName']['text'] as String;
    final address = place['formattedAddress'] as String;
    // Foursquare rating is 0–10; divide by 2 for 5-star display
    final rating = ((place['rating'] as num?)?.toDouble() ?? 0.0) / 2.0;
    final lat = _lat(place);
    final lng = _lng(place);
    final openNow = place['openNow'] as bool?;
    final openingHours = place['openingHours'] as String?;
    final hoursDisplay = place['hoursDisplay'] as String?;
    final phone = place['phone'] as String?;
    final website = place['website'] as String?;
    final tips = (place['tips'] as List?)?.cast<String>() ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
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
              // Handle
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
              const SizedBox(height: 16),

              // Name
              Text(
                name,
                style: const TextStyle(
                  color: kPurple,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Rating
              Row(
                children: [
                  ...List.generate(5, (i) {
                    if (i < rating.floor()) {
                      return const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 20,
                      );
                    } else if (i < rating) {
                      return const Icon(
                        Icons.star_half_rounded,
                        color: Colors.amber,
                        size: 20,
                      );
                    } else {
                      return const Icon(
                        Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 20,
                      );
                    }
                  }),
                  const SizedBox(width: 8),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Address
              _infoRow(Icons.location_on_outlined, address),

              // Opening hours (Foursquare human-readable, or raw OSM tag)
              if ((hoursDisplay ?? openingHours) != null) ...[
                const SizedBox(height: 10),
                _infoRow(
                  Icons.schedule_outlined,
                  hoursDisplay ?? openingHours!,
                  color: openNow == true ? Colors.green.shade600 : null,
                ),
              ],

              // Phone
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse('tel:$phone')),
                  child: _infoRow(Icons.phone_outlined, phone, color: kPurple),
                ),
              ],

              // Website
              if (website != null && website.isNotEmpty) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(website), mode: LaunchMode.externalApplication),
                  child: _infoRow(Icons.language_outlined, website, color: kPurple),
                ),
              ],

              // Tips / reviews
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'What people say',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                ...tips.take(3).map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.format_quote, size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (lat != null && lng != null) ...[
                const SizedBox(height: 24),

                // View on map (moves camera, closes sheet)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _mapController.move(LatLng(lat, lng), 15);
                    },
                    icon: const Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: kPurple,
                    ),
                    label: const Text(
                      'View on map',
                      style: TextStyle(color: kPurple),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPurple),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Get directions (opens Google Maps)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                      );
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.directions_outlined, size: 18),
                    label: const Text('Get directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helpers
  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color ?? Colors.grey.shade500, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color ?? Colors.black87,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class RecentSearch {
  List<Address> addresses = [];
}

List<Map<String, dynamic>> encodeItems(List<Address> items) {
  return items
      .map((a) => {'name': a.name, 'lat': a.lat, 'lon': a.lon})
      .toList();
}

List<Address> decodeItems(List saved) {
  return saved
      .map((e) => Address(name: e['name'], lat: e['lat'], lon: e['lon']))
      .toList();
}
