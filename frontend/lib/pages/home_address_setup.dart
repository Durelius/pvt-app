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

class HomeAddressSetupPage extends StatefulWidget {
  const HomeAddressSetupPage({super.key});

  @override
  State<HomeAddressSetupPage> createState() => _HomeAddressSetupPageState();
}

class _HomeAddressSetupPageState extends State<HomeAddressSetupPage> {
  final Debouncer _debouncer = Debouncer();
  final TextEditingController _controller = TextEditingController();
  final MapboxGeocodingService _geocoding = MapboxGeocodingService();
  final LocationService _locationService = LocationService();

  List<Address> _suggestions = [];
  Address? _picked;
  bool _saving = false;
  bool _loadingLocation = false;

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
        final box = Hive.box('homeAddress');
        box.put('homeAddress', jsonEncode({
          'name': _picked!.name,
          'lat': _picked!.lat,
          'lon': _picked!.lon,
        }));
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save address (${res.statusCode})')),
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set your home address',
                  style: TextStyle(
                    color: _kPurple,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your home address is shared with friends so they can add it when planning group meetups.',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
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
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_picked != null && !_saving) ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      disabledBackgroundColor: _kPurple.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
