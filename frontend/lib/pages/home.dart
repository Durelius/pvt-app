import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onIncrement});
  final VoidCallback onIncrement;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;
  Set<String> _selections = {'Profile'};

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    widget.onIncrement();
  }

  @override
  Widget build(BuildContext context) {
    return Stack( //replaced center with stack to place map as background.
      children: [
        FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(59.40, 17.94),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
                additionalOptions: const {
                  'attribution': '© OpenStreetMap contributors',
                },
              ),
            ],
          ),
        
        //ui on top of the map.
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: _incrementCounter,
                tooltip: 'Increment',
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 10),
              const Text(
                'You have pushed the button this many times:',
                style: TextStyle(color: Colors.white),
              ),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Profile',
                      label: Text('Profile'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: 'Plan',
                      icon: Icon(Icons.add),
                      label: Text('Plan'),
                    ),
                    ButtonSegment(
                      value: 'Saved',
                      label: Text('Saved'),
                      icon: Icon(Icons.bookmark),
                    ),
                  ],
                  selected: _selections,
                  style: SegmentedButton.styleFrom(
                    overlayColor: const Color(0xFF99D98C),
                    shadowColor: const Color(0xFF99D98C),
                    backgroundColor: Colors.white,
                  ),
                  onSelectionChanged: (Set<String> newSelection) {
                    if (newSelection.isNotEmpty) {
                      setState(() => _selections = newSelection);
                    }
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}