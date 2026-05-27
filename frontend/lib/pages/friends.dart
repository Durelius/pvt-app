import 'package:flutter/material.dart';
import '../main.dart' show notifications;
import '../services/friends_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const kPurpleFriends = Color(0xFF63519F);

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<FriendUser> _friends = [];
  List<PendingRequest> _pending = [];
  List<FriendUser> _sent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      FriendsService.getFriends(),
      FriendsService.getPendingRequests(),
      FriendsService.getNotifications(),
      FriendsService.getSentRequests(),
    ]);
    final friends = results[0] as List<FriendUser>;
    final pending = results[1] as List<PendingRequest>;
    final notifs = results[2] as List<AppNotification>;
    final sent = results[3] as List<FriendUser>;

    if (pending.isNotEmpty) {
      notifications.show(
        0,
        'Friend request',
        '${pending.first.sender.name} wants to be your friend',
        const NotificationDetails(
          android: AndroidNotificationDetails('friends', 'Friend Requests'),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }

    for (int i = 0; i < notifs.length; i++) {
      notifications.show(
        100 + i,
        'Friends',
        notifs[i].message,
        const NotificationDetails(
          android: AndroidNotificationDetails('friends', 'Friend Requests'),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
    if (notifs.isNotEmpty) {
      FriendsService.markNotificationsRead();
    }

    if (mounted) {
      setState(() {
        _friends = friends;
        _pending = pending;
        _sent = sent;
        _loading = false;
      });
    }
  }

  Future<void> _accept(PendingRequest req) async {
    await FriendsService.acceptRequest(req.id);
    _load();
  }

  Future<void> _decline(PendingRequest req) async {
    await FriendsService.declineRequest(req.id);
    _load();
  }

  Future<void> _removeFriend(FriendUser friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend'),
        content: Text('Remove ${friend.name} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await FriendsService.removeFriend(friend.id);
    if (!mounted) return;
    if (ok) _load();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '${friend.name} removed.' : 'Something went wrong.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEEF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5C3DAB),
        title: const Text('Friends', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_pending.isNotEmpty) ...[
                    const Text('Friend Requests',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._pending.map((req) => _PendingCard(
                          request: req,
                          onAccept: () => _accept(req),
                          onDecline: () => _decline(req),
                        )),
                    const SizedBox(height: 20),
                  ],
                  if (_sent.isNotEmpty) ...[
                    const Text('Pending',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._sent.map((u) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: _Avatar(name: u.name, pictureUrl: u.picture),
                            title: Text(u.name),
                            subtitle: const Text('Waiting for response...'),
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],
                  const Text('Friends',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('No friends yet.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ..._friends.map((f) => _FriendTile(
                        friend: f,
                        onRemove: () => _removeFriend(f),
                      )),
                ],
              ),
            ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final PendingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PendingCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _Avatar(name: request.sender.name, pictureUrl: request.sender.picture),
        title: Text(request.sender.name),
        subtitle: const Text('wants to be your friend'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onDecline,
              child: const Text('Decline', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: onAccept,
              child: const Text('Accept',
                  style: TextStyle(color: kPurpleFriends)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final FriendUser friend;
  final VoidCallback onRemove;

  const _FriendTile({required this.friend, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _Avatar(name: friend.name, pictureUrl: friend.picture),
        title: Text(friend.name),
        trailing: IconButton(
          icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
          onPressed: onRemove,
          tooltip: 'Remove friend',
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String pictureUrl;

  const _Avatar({required this.name, this.pictureUrl = ''});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase();
    final hasPhoto = pictureUrl.isNotEmpty;
    return CircleAvatar(
      backgroundColor: kPurpleFriends,
      foregroundImage: hasPhoto ? NetworkImage(pictureUrl) : null,
      onForegroundImageError: hasPhoto ? (e, s) {} : null,
      child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 14)),
    );
  }
}
