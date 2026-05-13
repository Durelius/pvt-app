import 'package:flutter/material.dart';
import 'package:flutter_debouncer/flutter_debouncer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../MapboxGeocodingService.dart';
import 'profile.dart';

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
  String searchTerm = "";

  //addresses stored
  final List<String> items = [];

  //list of results when searching for the middle
  List<dynamic> _results = [];

  void onTextChanged(String searchParam) {
    debouncer.debounce(const Duration(milliseconds: 400), () async {
      searchTerm = searchParam;
      print('Söker efter: $searchTerm'); // skrivs ut när debounce triggar

      if (searchTerm.trim().length < 4) {
        setState(() => suggestions = []);
        return;
      }
      final results = await geocoding.getSuggestions(searchTerm);
      setState(() => suggestions = results);
    });
  }

  void selectSuggestion(Address address) {
    mapController.move(
      LatLng(address.lat, address.lon),
      15,
    ); // flytta kartan till vald adress
    setState(() {
      suggestions = [];
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

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Home"),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.menu),

          onSelected: (value) {
            if (value == 'profile') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfilePage(),
                ),
              );
            }

            if (value == 'settings') {
              //go to settings
            }

            if (value == 'darkmode') {
              setState(() {
                isDarkMode = !isDarkMode;
                //gör något?
              });
            }
          },

          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'Profile',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.black),
                  SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'darkmode',
              child: StatefulBuilder(
                builder: (context, setStatePopup) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Dark mode",
                        style: TextStyle(color: Colors.black),
                      ),

                      Switch(
                        value: isDarkMode,
                        activeColor: const Color(0xFF63519F),
                        onChanged: (value) {
                          setState(() {
                            isDarkMode = value;
                          });

                          setStatePopup(() {});
                        },
                      ),
                    ],
                  );
                },
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
                  if (suggestions.isNotEmpty)
                    Card(
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) => ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(suggestions[index].name),
                          onTap: () => selectSuggestion(suggestions[index]),
                        ),
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