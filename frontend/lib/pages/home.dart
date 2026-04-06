import 'package:flutter/material.dart';

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

      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              onPressed: _incrementCounter,
              tooltip: 'Increment',
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 10),
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Profile',
                      label: Text('Profile'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: 'Plan',
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 5),
                          Icon(Icons.add, size: 30),
                          Text('Plan', style: TextStyle(fontSize: 10)),
                          SizedBox(height: 5),
                        ],
                      ),
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
                    setState(() => _selections = newSelection);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}