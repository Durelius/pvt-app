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
const Color _kPurple = Color(0xFF63519F);

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
  final MapboxGeocodingService geocoding = MapboxGeocodingService();
  final FocusNode _focusNode = FocusNode();
  List<Address> suggestions = [];
  List<FriendUser> userSuggestions = [];
  String searchTerm = "";
  int _pendingFriendCount = 0;
  List<FriendUser> _friends = [];
  List<PendingRequest> _pendingRequests = [];
  Set<int> _sentRequestUserIds = {};

  final List<String> items = [];
  List<dynamic> _results = [];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {});
    });
    _refreshData();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!AuthService.instance.isLoggedIn) return;
    final results = await Future.wait([
      FriendsService.getFriends(),
      FriendsService.getPendingRequests(),
      FriendsService.getSentRequests(),
    ]);
    if (!mounted) return;
    final friends = results[0] as List<FriendUser>;
    final pending = results[1] as List<PendingRequest>;
    final sent = results[2] as List<FriendUser>;
    setState(() {
      _friends = friends;
      _pendingRequests = pending;
      _pendingFriendCount = pending.length;
      _sentRequestUserIds = sent.map((u) => u.id).toSet();
    });
  }

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

    final isConfirmed = _friends.any((f) => f.id == user.id);
    if (isConfirmed) {
      final friend = _friends.firstWhere((f) => f.id == user.id);
      if (friend.hasHomeAddress) {
        mapController.move(LatLng(friend.homeAddressLat, friend.homeAddressLon), 15);
      }
      return;
    }

    final incoming = _pendingRequests.where((r) => r.sender.id == user.id).firstOrNull;
    if (incoming != null) {
      final accept = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(user.name),
          content: Text('${user.name} has sent you a friend request.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Accept', style: TextStyle(color: Color(0xFF63519F))),
            ),
          ],
        ),
      );
      if (accept == null || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final ok = accept
          ? await FriendsService.acceptRequest(incoming.id)
          : await FriendsService.declineRequest(incoming.id);
      if (!mounted) return;
      if (ok) await _refreshData();
      messenger.showSnackBar(SnackBar(
        content: Text(ok
            ? (accept ? 'You are now friends with ${user.name}!' : 'Request declined.')
            : 'Something went wrong.'),
      ));
      return;
    }

    if (_sentRequestUserIds.contains(user.id)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(user.name),
          content: Text('Waiting for ${user.name} to accept your friend request.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

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
    final messenger = ScaffoldMessenger.of(context);
    final ok = await FriendsService.sendFriendRequest(user.id);
    if (!mounted) return;
    if (ok) await _refreshData();
    messenger.showSnackBar(SnackBar(
      content: Text(ok ? 'Friend request sent to ${user.name}!' : 'Could not send request.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              MarkerLayer(
                markers: _friends
                    .where((f) => f.hasHomeAddress)
                    .map((f) => Marker(
                          point: LatLng(f.homeAddressLat, f.homeAddressLon),
                          width: 120,
                          height: 60,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  f.name,
                                  style: const TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.place, color: _kPurple, size: 28),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: _focusNode,
                          cursorColor: Colors.black,
                          cursorWidth: 2,
                          showCursor: true,
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: TextStyle(
                              color: _focusNode.hasFocus
                                  ? Colors.transparent
                                  : Colors.black,
                            ),
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
                      ),
                      const SizedBox(width: 8),
                      _MenuButton(
                        hasBadge: _pendingFriendCount > 0,
                        onSelected: (value) {
                          void goToLogin() {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginScreen()),
                            );
                          }

                          if (value == 'close') return;

                          final bool isLoggedIn = AuthService.instance.isLoggedIn;

                          _focusNode.unfocus();

                          if (value == 'profile') {
                            if (!isLoggedIn) { goToLogin(); return; }
                            Navigator.push(context,
                                MaterialPageRoute(builder: (context) => const ProfilePage()));
                          }
                          if (value == 'friends') {
                            if (!isLoggedIn) { goToLogin(); return; }
                            Navigator.push(context,
                                MaterialPageRoute(builder: (context) => const FriendsPage()))
                              .then((_) => _refreshData());
                          }
                          if (value == 'settings') {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (context) => const SettingsPage()));
                          }
                        },
                        pendingFriendCount: _pendingFriendCount,
                      ),
                    ],
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

class _MenuButton extends StatelessWidget {
  final bool hasBadge;
  final int pendingFriendCount;
  final void Function(String) onSelected;

  const _MenuButton({
    required this.hasBadge,
    required this.pendingFriendCount,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        onSelected: onSelected,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.menu, color: Colors.black87),
            if (hasBadge)
              const Positioned(
                top: -3,
                right: -3,
                child: _BadgeDot(),
              ),
          ],
        ),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'close',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.close, color: Colors.black54),
              ],
            ),
          ),
          const PopupMenuDivider(height: 1),
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
          PopupMenuItem(
            value: 'friends',
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.black),
                const SizedBox(width: 10),
                const Text('Friends', style: TextStyle(color: Colors.black)),
                if (pendingFriendCount > 0) ...[
                  const SizedBox(width: 8),
                  const _BadgeDot(),
                ],
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
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}
