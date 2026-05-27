import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

class FriendUser {
  final int id;
  final String name;
  final String picture;
  final String homeAddressName;
  final double homeAddressLat;
  final double homeAddressLon;

  FriendUser({
    required this.id,
    required this.name,
    required this.picture,
    this.homeAddressName = '',
    this.homeAddressLat = 0.0,
    this.homeAddressLon = 0.0,
  });

  bool get hasHomeAddress => homeAddressName.isNotEmpty;

  factory FriendUser.fromJson(Map<String, dynamic> j) => FriendUser(
        id: j['id'],
        name: j['name'] ?? '',
        picture: j['picture'] ?? '',
        homeAddressName: j['home_address_name'] ?? '',
        homeAddressLat: (j['home_address_lat'] as num?)?.toDouble() ?? 0.0,
        homeAddressLon: (j['home_address_lon'] as num?)?.toDouble() ?? 0.0,
      );
}

class AppNotification {
  final int id;
  final String message;

  AppNotification({required this.id, required this.message});

  factory AppNotification.fromJson(Map<String, dynamic> j) =>
      AppNotification(id: j['id'], message: j['message']);
}

class PendingRequest {
  final int id;
  final FriendUser sender;

  PendingRequest({required this.id, required this.sender});

  factory PendingRequest.fromJson(Map<String, dynamic> j) => PendingRequest(
        id: j['id'],
        sender: FriendUser.fromJson(j['sender'] as Map<String, dynamic>),
      );
}

class FriendsService {
  static const _base = '$apiBase/user/v1/auth';

  static Map<String, String> get _headers => AuthService.instance.authHeaders;

  static Future<List<FriendUser>> searchUsers(String q) async {
    final uri = Uri.parse('$_base/search').replace(queryParameters: {'q': q});
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => FriendUser.fromJson(e)).toList();
  }

  static Future<bool> sendFriendRequest(int receiverId) async {
    final res = await http.post(
      Uri.parse('$_base/friends/request'),
      headers: _headers,
      body: jsonEncode({'receiver_id': receiverId}),
    );
    return res.statusCode == 204;
  }

  static Future<List<FriendUser>> getFriends() async {
    final res = await http.get(Uri.parse('$_base/friends'), headers: _headers);
    if (res.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => FriendUser.fromJson(e)).toList();
  }

  static Future<List<PendingRequest>> getPendingRequests() async {
    final res = await http.get(Uri.parse('$_base/friends/pending'), headers: _headers);
    if (res.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => PendingRequest.fromJson(e)).toList();
  }

  static Future<List<FriendUser>> getSentRequests() async {
    final res = await http.get(Uri.parse('$_base/friends/sent'), headers: _headers);
    if (res.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => FriendUser.fromJson(e)).toList();
  }

  static Future<bool> removeFriend(int friendId) async {
    final res = await http.delete(
      Uri.parse('$_base/friends/$friendId'),
      headers: _headers,
    );
    return res.statusCode == 204;
  }

  static Future<List<AppNotification>> getNotifications() async {
    final res = await http.get(Uri.parse('$_base/notifications'), headers: _headers);
    if (res.statusCode != 200) return [];
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => AppNotification.fromJson(e)).toList();
  }

  static Future<void> markNotificationsRead() async {
    await http.put(Uri.parse('$_base/notifications/read'), headers: _headers);
  }

  static Future<bool> acceptRequest(int id) async {
    final res = await http.put(
      Uri.parse('$_base/friends/$id/accept'),
      headers: _headers,
    );
    return res.statusCode == 204;
  }

  static Future<bool> declineRequest(int id) async {
    final res = await http.put(
      Uri.parse('$_base/friends/$id/decline'),
      headers: _headers,
    );
    return res.statusCode == 204;
  }
}
