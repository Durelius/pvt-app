import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mitten/location_service/location_service.dart';

import '../MapboxGeocodingService.dart';
import '../config.dart';
import '../services/auth_service.dart';

const Color _kPurple = Color(0xFF63519F);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Debouncer _debouncer = Debouncer();
  final TextEditingController _controller = TextEditingController();
  final MapboxGeocodingService _geocoding = MapboxGeocodingService();
  final LocationService _locationService = LocationService();
  final _homeAddressBox = Hive.box('homeAddress');

  List<Address> _suggestions = [];
  Address? _picked;
  bool _saving = false;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    final raw = _homeAddressBox.get('homeAddress');
    if (raw != null) {
      try {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        _picked = Address(
          name: data['name'] as String,
          lat: (data['lat'] as num).toDouble(),
          lon: (data['lon'] as num).toDouble(),
        );
        _controller.text = _picked!.name;
      } catch (_) {}
    }
  }

  void _onTextChanged(String value) {
    _picked = null;
    _debouncer.debounce(const Duration(milliseconds: 400), () async {
      if (value.trim().length < 4) {
        setState(() => _suggestions = []);
        return;
      }
      final results = await _geocoding.getSuggestions(value.trim());
      setState(() => _suggestions = results);
    });
  }

  void _pick(Address address) {
    setState(() {
      _picked = address;
      _controller.text = address.name;
      _suggestions = [];
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final loc = await _locationService.getCurrentLocation();
      final address = await _geocoding.reverseGeocode(loc.latitude, loc.longitude);
      if (address != null) {
        _pick(address);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find address for your location')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _save() async {
    if (_picked == null || _saving) return;
    setState(() => _saving = true);

    try {
      final res = await http.put(
        Uri.parse('$apiBase/user/v1/auth/home-address'),
        headers: AuthService.instance.authHeaders,
        body: jsonEncode({'name': _picked!.name, 'lat': _picked!.lat, 'lon': _picked!.lon}),
      );

      if (!mounted) return;

      if (res.statusCode == 204) {
        _homeAddressBox.put('homeAddress', jsonEncode({
          'name': _picked!.name,
          'lat': _picked!.lat,
          'lon': _picked!.lon,
        }));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Home address saved')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save (${res.statusCode})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
              ],
            ),
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEADDFF),
                    maxRadius: 75,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Icon(Icons.person, color: Color(0xFF4F378A)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('My Profile', style: TextStyle(color: Color(0xFF4F378A))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Home address',
              style: TextStyle(
                color: _kPurple,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search for your address...',
                filled: true,
                fillColor: const Color(0xFFF3F0FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: _kPurple),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _picked = null;
                            _suggestions = [];
                          });
                        },
                      )
                    : null,
              ),
              onChanged: _onTextChanged,
            ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: _kPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15),
                    indent: 44,
                  ),
                  itemBuilder: (_, i) {
                    final parts = _suggestions[i].name.split(',');
                    final street = parts.first.trim();
                    final rest = parts.skip(1).join(',').trim();
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on, color: Colors.white70, size: 20),
                      title: Text(street,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: rest.isNotEmpty
                          ? Text(rest,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12))
                          : null,
                      onTap: () => _pick(_suggestions[i]),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadingLocation ? null : _useCurrentLocation,
              icon: _loadingLocation
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple),
                    )
                  : const Icon(Icons.my_location, size: 16, color: _kPurple),
              label: const Text('Use current location', style: TextStyle(color: _kPurple, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kPurple),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_picked != null && !_saving) ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  disabledBackgroundColor: _kPurple.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
