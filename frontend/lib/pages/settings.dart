import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _locationEnabled = false;

  Future<void> _clearCache() async {
    await Hive.box<dynamic>('addressEntries').clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEEF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5C3DAB),
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Location tile
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                title: const Text('Allow Location'),
                subtitle: const Text('Let Mitten access your location'),
                secondary: const Icon(Icons.location_on, color: Color(0xFF5C3DAB)),
                value: _locationEnabled,
                activeColor: const Color(0xFF99D98C),
                onChanged: (value) {
                  setState(() => _locationEnabled = value);
                },
              ),
            ),
            const SizedBox(height: 12),

            // Clear cache tile
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFF5C3DAB)),
                title: const Text('Clear Cache'),
                subtitle: const Text('Remove all saved local data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // Confirm dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear Cache'),
                      content: const Text('Are you sure you want to clear all cached data?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) _clearCache();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}