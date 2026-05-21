import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../MapboxGeocodingService.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import 'login.dart';
import 'profile.dart';
import 'friends.dart';
import 'settings.dart';

final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN']!;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isDarkMode = false;
  final Debouncer debouncer = Debouncer();
  final TextEditingController controller = TextEditingController();
  final MapController mapController = MapController();
  //Mapbox API
  final MapboxGeocodingService geocoding = MapboxGeocodingService();
  List<Address> suggestions = [];
  List<FriendUser> userSuggestions = [];
  String searchTerm = "";

  //addresses stored
  final List<String> items = [];

  //list of results when searching for the middle
  List<dynamic> _results = [];

  void onTextChanged(String searchParam) {
    debouncer.debounce(const Duration(milliseconds: 400), () async {
      searchTerm = searchParam;

      if (searchTerm.trim().length < 2) {
        setState(() { suggestions = []; userSuggestions = []; });
        return;
      }

      final addressFuture = searchTerm.trim().length >= 4
          ? geocoding.getSuggestions(searchTerm)
          : Future.value(<Address>[]);

      final userFuture = AuthService.instance.isLoggedIn
          ? FriendsService.searchUsers(searchTerm.trim())
          : Future.value(<FriendUser>[]);

      final results = await Future.wait([addressFuture, userFuture]);
      setState(() {
        suggestions = results[0] as List<Address>;
        userSuggestions = results[1] as List<FriendUser>;
      });
    });
  }

  void selectSuggestion(Address address) {
    mapController.move(LatLng(address.lat, address.lon), 15);
    setState(() {
      suggestions = [];
      userSuggestions = [];
      controller.clear();
      searchTerm = "";
    });
  }

  void addItem() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      items.add(controller.text.trim());
      controller.clear();
    });
  }

  Future<void> _showFriendRequestDialog(FriendUser user) async {
    setState(() { suggestions = []; userSuggestions = []; controller.clear(); searchTerm = ""; });
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.name),
        content: Text('Add ${user.name} as a friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add Friend', style: TextStyle(color: Color(0xFF63519F))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await FriendsService.sendFriendRequest(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Friend request sent to ${user.name}!' : 'Could not send request.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),

            onSelected: (value) {
              void goToLogin() {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }

              final bool isLoggedIn = AuthService.instance.isLoggedIn;

              if (value == 'profile') {
                if (!isLoggedIn) {
                  goToLogin();
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              }

              if (value == 'friends') {
                if (!isLoggedIn) {
                  goToLogin();
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendsPage()),
                );
              }

              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              }
            },

            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.black),
                    SizedBox(width: 10),
                    Text('Profile', style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),

              const PopupMenuItem(
                value: 'friends',
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.black),
                    SizedBox(width: 10),
                    Text('Friends', style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),

              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.black),
                    SizedBox(width: 10),
                    Text('Settings', style: TextStyle(color: Colors.black)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: const MapOptions(
              initialCenter: LatLng(59.33, 18.07),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxToken',
                userAgentPackageName: 'com.example.app',
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors © Mapbox',
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.02,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Sök adress...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: onTextChanged,
                    onSubmitted: (_) => addItem(),
                  ),
                  if (searchTerm.isNotEmpty && suggestions.isEmpty && userSuggestions.isEmpty)
                    const Card(
                      child: ListTile(title: Text("No suggestions found")),
                    ),
                  if (userSuggestions.isNotEmpty || suggestions.isNotEmpty)
                    Card(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          ...userSuggestions.map((u) => ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(u.name),
                                onTap: () => _showFriendRequestDialog(u),
                              )),
                          ...suggestions.map((a) => ListTile(
                                leading: const Icon(Icons.location_on),
                                title: Text(a.name),
                                onTap: () => selectSuggestion(a),
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
