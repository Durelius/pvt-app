import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN']!;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),

            onSelected: (value) {
              if (value == 'settings') {
                print("Go to settings");
              }

              if (value == 'darkmode') {
                setState(() {
                  isDarkMode = !isDarkMode;
                });

                print("Dark mode: $isDarkMode");
              }
            },

            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Text(
                  'Settings',
                  style: TextStyle(color: Colors.black),
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

                            //print("Dark mode: $value");
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

      body: FlutterMap(
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
              TextSourceAttribution('© OpenStreetMap contributors © Mapbox'),
            ],
          ),
        ],
      ),
    );
  }
}