import 'package:flutter/material.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController searchController = TextEditingController();

  // Exempel-lista med vänner
  final List<String> allFriends = [
    'Alice',
    'Bob',
    'Charlie',
    'David',
    'Emma',
    'Felix',
    'Isak',
    'Julia',
    'Lucas',
  ];

  List<String> filteredFriends = [];

  @override
  void initState() {
    super.initState();
    filteredFriends = allFriends;
  }

  void searchFriends() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredFriends = allFriends.where((friend) {
        return friend.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                ElevatedButton(
                  onPressed: searchFriends,
                  child: const Text('Search'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: filteredFriends.length,

                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(filteredFriends[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}