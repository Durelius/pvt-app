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
    return Center(
      // Center is a layout widget. It takes a single child and positions it
      // in the middle of the parent.
      // Column is also a layout widget. It takes a list of children and
      // arranges them vertically. By default, it sizes itself to fit its
      // children horizontally, and tries to be as tall as its parent.
      //
      // Column has various properties to control how it sizes itself and
      // how it positions its children. Here we use mainAxisAlignment to
      // center the children vertically; the main axis here is the vertical
      // axis because Columns are vertical (the cross axis would be
      // horizontal).
      //
      // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
      // action in the IDE, or press "p" in the console), to see the
      // wireframe for each widget.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 200,
              width: 200,

              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(59.40, 17.94),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',

                    additionalOptions: const {
                      'attribution': '© OpenStreetMap contributors',
                    },
                  ),
                ],
              ),
            ),
          ),

          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          const Text('You have pushed the button this many times:'),
          Text('$_counter', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),

          SegmentedButton<String>(
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
            ),

            onSelectionChanged: (Set<String> newSelection) {
              if (newSelection.isNotEmpty) {
                setState(() => _selections = newSelection);
              }
            },
          ),
        ],
      ),
    );
  }
}
