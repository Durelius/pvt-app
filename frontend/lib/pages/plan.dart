import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
String _locationType = 'cafe';

class PlanPage extends StatefulWidget {
  final AppLocation? currentLocation;
  const PlanPage({super.key, this.currentLocation});

  @override
  State<PlanPage> createState() => PlanPageState();
}

class PlanPageState extends State<PlanPage> with AutomaticKeepAliveClientMixin{
  final Debouncer _debouncer = Debouncer();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final MapboxGeocodingService _geocoding = MapboxGeocodingService();
  final MapController _mapController = MapController();

  bool _hasCurrentLocation = false;
  bool _isLoadingLocation = false;
  AppLocation? _fetchedCurrentLocation;
  bool _hasMyAddress = false;
  bool _isFocused = false;
  String _homeAddressName = '';
  final homeAddressBox = Hive.box('homeAddress');

  List<Address> _suggestions = [];
  List<FriendUser> _friendSuggestions = [];
  List<FriendUser> _friends = [];
  String _searchTerm = "";
  final List<Address> _items = [];
  int _searchVersion = 0;
  List<dynamic> _results = [];
  bool _isLoading = false;
  List<Map<String, dynamic>> _groupSuggestions = [];


  @override
  void initState() {
    super.initState();

    if (AuthService.instance.isLoggedIn) _loadFriends();

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _resolveCurrentAddress(double lat, double lng) async {
    final address = await _geocoding.reverseGeocode(lat, lng);
    if (!mounted) return;
    setState(() => _items.add(Address(
      name: address?.name ?? '$lat, $lng',
      lat: lat,
      lon: lng,
    )));
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
        setState(() { _suggestions = []; _friendSuggestions = []; _groupSuggestions = []; });
        return;
      }

      // Grupper
      final groupBox = Hive.box('savedGroups');
      final matchingGroups = groupBox.keys
          .map((k) => groupBox.get(k) as Map)
          .where((g) => (g['name'] as String).toLowerCase().contains(term.toLowerCase()))
          .map((g) => {'name': g['name'] as String, 'addresses': g['addresses'] as List})
          .toList();

      final matchingFriends = _friends
        .where((f) => f.name.toLowerCase().contains(term.toLowerCase()))
        .toList();

      if (term.length < 4) {
        setState(() {
          _suggestions = [];
          _friendSuggestions = matchingFriends;
          _groupSuggestions = matchingGroups;
        });
        return;
      }

      final version = ++_searchVersion;
      final results = await _geocoding.getSuggestions(_searchTerm);
      if (version == _searchVersion) {
        setState(() {
          _suggestions = results;
          _friendSuggestions = matchingFriends;
          _groupSuggestions = matchingGroups;
        });
      }
    });
  }

  void loadAddresses(List<Address> addresses) {
    setState(() {
      _items.clear();
      _items.addAll(addresses);
      _results = [];
      _hasMyAddress = false;
      _hasCurrentLocation = false;
      _fetchedCurrentLocation = null;
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
      _groupSuggestions = [];
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
        queryParameters: {'points': pointsJson, 'location_type': _locationType},
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
    super.build(context);
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
                      _groupSuggestions = [];
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
                    cursorColor: Colors.white,
                    cursorWidth: 2,
                    showCursor: true,
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                    hintText: _focusNode.hasFocus ? '' : 'Add an address...',
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
                          _groupSuggestions = [];
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
          if (_friendSuggestions.isNotEmpty || _suggestions.isNotEmpty || _groupSuggestions.isNotEmpty)
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
                itemCount: _groupSuggestions.length + _friendSuggestions.length + _suggestions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                  indent: 52,
                ),
                itemBuilder: (context, i) {
                  // Grupper först
                  if (i < _groupSuggestions.length) {
                    final group = _groupSuggestions[i];
                    final count = (group['addresses'] as List).length;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.groups, color: Colors.white70, size: 22),
                      title: Text(
                        group['name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                      ),
                      subtitle: Text(
                        '$count addresses',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.65)),
                      ),
                      trailing: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 17),
                      ),
                      onTap: () => _selectGroup(group),
                    );
                  }

                  // Sedan vänner
                  final afterGroups = i - _groupSuggestions.length;
                  if (afterGroups < _friendSuggestions.length) {
                    final friend = _friendSuggestions[afterGroups];
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
                  final idx = i - _groupSuggestions.length - _friendSuggestions.length;
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
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: (_hasCurrentLocation || _isLoadingLocation) ? null : () async {
                      setState(() => _isLoadingLocation = true);
                      try {
                        final loc = await LocationService().getCurrentLocation();
                        if (!mounted) return;
                        setState(() {
                          _fetchedCurrentLocation = loc;
                          _hasCurrentLocation = true;
                          _isLoadingLocation = false;
                        });
                        _resolveCurrentAddress(loc.latitude, loc.longitude);
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _isLoadingLocation = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    },
                    icon: _isLoadingLocation
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kPurple))
                        : const Icon(Icons.my_location, size: 16, color: kPurple),
                    label: const Text('Current location', style: TextStyle(color: kPurple, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPurple),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: OutlinedButton.icon(
                    onPressed: _hasMyAddress ? null : () {
                      final raw = homeAddressBox.get('homeAddress');
                      if (raw == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No home address saved in profile')));
                        return;
                      }
                      try {
                        final data = jsonDecode(raw as String) as Map<String, dynamic>;
                        setState(() {
                          _hasMyAddress = true;
                          _homeAddressName = data['name'] as String;
                          _items.add(Address(
                            name: data['name'] as String,
                            lat: (data['lat'] as num).toDouble(),
                            lon: (data['lon'] as num).toDouble(),
                          ));
                        });
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No home address saved in profile')));
                      }
                    },
                    icon: const Icon(Icons.home_outlined, size: 16, color: kPurple),
                    label: const Text('My address', style: TextStyle(color: kPurple, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kPurple),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: OutlinedButton(
                  onPressed: _showLocationTypePicker,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kPurple),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_locationTypeIcon(_locationType), size: 16, color: kPurple),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more, size: 16, color: kPurple),
                    ],
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
                          if (removed.lat == _fetchedCurrentLocation?.latitude &&
                              removed.lon == _fetchedCurrentLocation?.longitude) {
                            _hasCurrentLocation = false;
                            _fetchedCurrentLocation = null;
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
            MarkerLayer(
              markers: _items
                  .map((item) => Marker(
                        point: LatLng(item.lat, item.lon),
                        width: 120,
                        height: 60,
                        child: Column(
                          children: [
                            const Icon(Icons.place, color: Colors.amber, size: 28),
                            Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                item.name.split(',').first,
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
              child: Stack(
                children: [
                  CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
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
                          ],
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        sliver: SliverList.builder(
                          itemCount: _results.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildPlaceCard(_results[i]),
                          ),
                        ),
                      ),
                    ],
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
              // efter de befintliga Row(children: [openBadge, cuisineChip, priceLevel])
            const SizedBox(height: 8),
            _buildAmenities(place),
            const SizedBox(height: 8),
            // befintlig address-rad
            ],
          ),
        ),
      ),
    );
  }

  IconData _locationTypeIcon(String type) {
    switch (type) {
      case 'restaurant': return Icons.restaurant;
      case 'bar': return Icons.local_bar;
      case 'park': return Icons.park;
      case 'library': return Icons.local_library;
      case 'cinema': return Icons.movie;
      default: return Icons.coffee;
    }
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
    final travelTimes = (place['travelTimes'] as List?)?.cast<int>() ?? [];

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
              // efter stjärn-raden + SizedBox(height: 16)
              const SizedBox(height: 16),
              _buildAmenities(place),
              const SizedBox(height: 16),

              // Travel times per person
              if (travelTimes.isNotEmpty && travelTimes.length == _items.length) ...[
                Row(
                  children: [
                    const Text(
                      'Travel times',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    const Spacer(),
                    Text(
                      'avg ${(travelTimes.reduce((a, b) => a + b) / travelTimes.length).round()} min',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...List.generate(travelTimes.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_transit, size: 16, color: kPurple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _items[i].name,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${travelTimes[i]} min',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kPurple,
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 6),
              ],

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
                      //-0.0035 är offset för att platsen ska hamna i mitten av vyn
                      _mapController.move(LatLng(lat-0.0035, lng), 15);
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

  void _showLocationTypePicker() {
    final options = [
      {'value': 'cafe', 'label': 'Café', 'icon': Icons.coffee},
      {'value': 'restaurant', 'label': 'Restaurant', 'icon': Icons.restaurant},
      {'value': 'bar', 'label': 'Bar', 'icon': Icons.local_bar},
      {'value': 'park', 'label': 'Park', 'icon': Icons.park},
      {'value': 'library', 'label': 'Library', 'icon': Icons.local_library},
      {'value': 'cinema', 'label': 'Cinema', 'icon': Icons.movie},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What kind of place?',
              style: TextStyle(
                color: kPurple,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options.map((opt) {
                final selected = _locationType == opt['value'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _locationType = opt['value'] as String);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? kPurple : kPurple.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: selected ? kPurple : kPurple.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          opt['icon'] as IconData,
                          size: 16,
                          color: selected ? Colors.white : kPurple,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          opt['label'] as String,
                          style: TextStyle(
                            color: selected ? Colors.white : kPurple,
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
      ),
    );
  }
  void _selectGroup(Map<String, dynamic> group) {
    _searchVersion++;
    _focusNode.unfocus();
    final addresses = decodeItems(group['addresses'] as List);
    setState(() {
      for (final a in addresses) {
        if (!_items.any((e) => e.lat == a.lat && e.lon == a.lon)) {
          _items.add(a);
        }
      }
      _suggestions = [];
      _friendSuggestions = [];
      _groupSuggestions = [];
      _searchTerm = '';
      _controller.clear();
    });
  }

  Widget _buildAmenities(Map<String, dynamic> place) {
    final chips = <_AmenityChip>[];

    // Wheelchair
    final wheelchair = place['wheelchair'] as String?;
    if (wheelchair == 'yes') {
      chips.add(_AmenityChip(icon: Icons.accessible, label: 'Wheelchair access', style: _ChipStyle.yes));
    } else if (wheelchair == 'limited') {
      chips.add(_AmenityChip(icon: Icons.accessible_forward, label: 'Limited access', style: _ChipStyle.neutral));
    }

    // WiFi
    if (place['wifi'] == true) {
      chips.add(_AmenityChip(icon: Icons.wifi, label: 'WiFi', style: _ChipStyle.yes));
    }

    // Smoking
    final smoking = place['smoking'] as String?;
    if (smoking == 'no') {
      chips.add(_AmenityChip(icon: Icons.smoke_free, label: 'No smoking', style: _ChipStyle.no));
    } else if (smoking == 'outside') {
      chips.add(_AmenityChip(icon: Icons.smoking_rooms, label: 'Smoking outside', style: _ChipStyle.neutral));
    } else if (smoking == 'yes') {
      chips.add(_AmenityChip(icon: Icons.smoking_rooms, label: 'Smoking allowed', style: _ChipStyle.bad));
    }

    // Outdoor seating
    if (place['outdoorSeating'] == true) {
      chips.add(_AmenityChip(icon: Icons.deck, label: 'Outdoor seating', style: _ChipStyle.yes));
    }

    // Dog friendly
    if (place['dogFriendly'] == true) {
      chips.add(_AmenityChip(icon: Icons.pets, label: 'Dog friendly', style: _ChipStyle.yes));
    }

    // Diet
    if (place['dietVegan'] == true) {
      chips.add(_AmenityChip(icon: Icons.eco, label: 'Vegan options', style: _ChipStyle.yes));
    }
    if (place['dietVegetarian'] == true) {
      chips.add(_AmenityChip(icon: Icons.spa, label: 'Vegetarian options', style: _ChipStyle.yes));
    }

    // Organic
    if (place['organic'] == true) {
      chips.add(_AmenityChip(icon: Icons.grass, label: 'Organic', style: _ChipStyle.yes));
    }

    // Takeaway
    if (place['takeaway'] == true) {
      chips.add(_AmenityChip(icon: Icons.takeout_dining, label: 'Takeaway', style: _ChipStyle.neutral));
    }

    // Cuisine
    final cuisine = (place['cuisine'] as String?)?.split(';').first;
    if (cuisine != null && cuisine.isNotEmpty) {
      chips.add(_AmenityChip(
        icon: Icons.restaurant,
        label: cuisine[0].toUpperCase() + cuisine.substring(1),
        style: _ChipStyle.info,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Row(
        children: chips
            .map((c) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildAmenityChip(c),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildAmenityChip(_AmenityChip chip) {
    Color bg, borderColor, textColor, iconColor;
    switch (chip.style) {
      case _ChipStyle.yes:
        bg = const Color(0xFFEAF3DE);
        borderColor = const Color(0xFF639922);
        textColor = const Color(0xFF3B6D11);
        iconColor = const Color(0xFF3B6D11);
        break;
      case _ChipStyle.no:
        bg = const Color(0xFFFCEBEB);
        borderColor = const Color(0xFFE24B4A);
        textColor = const Color(0xFFA32D2D);
        iconColor = const Color(0xFFA32D2D);
        break;
      case _ChipStyle.bad:
        bg = const Color(0xFFFAECE7);
        borderColor = const Color(0xFFD85A30);
        textColor = const Color(0xFF993C1D);
        iconColor = const Color(0xFF993C1D);
        break;
      case _ChipStyle.info:
        bg = const Color(0xFFE6F1FB);
        borderColor = const Color(0xFF378ADD);
        textColor = const Color(0xFF185FA5);
        iconColor = const Color(0xFF185FA5);
        break;
      case _ChipStyle.neutral:
      default:
        bg = const Color(0xFFF1EFE8);
        borderColor = const Color(0xFFB4B2A9);
        textColor = const Color(0xFF5F5E5A);
        iconColor = const Color(0xFF5F5E5A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(
            chip.label,
            style: TextStyle(fontSize: 12, color: textColor, height: 1),
          ),
        ],
      ),
    );
  }
  @override
  bool get wantKeepAlive => true;
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

enum _ChipStyle { yes, no, bad, info, neutral }

class _AmenityChip {
  final IconData icon;
  final String label;
  final _ChipStyle style;
  const _AmenityChip({required this.icon, required this.label, required this.style});
}
