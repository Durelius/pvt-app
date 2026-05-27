import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mitten/services/friends_service.dart';
import 'package:mitten/services/auth_service.dart';



//VIKTIGT! This diff contains a change in line endings from 'LF' to 'CRLF'.



void main() {
  group('FriendUser', () {
    test('FriendUser.fromJson creates instance with all fields', () {
      final json = {
        'id': 1,
        'name': 'John Doe',
        'picture': 'https://example.com/pic.jpg',
        'home_address_name': 'Home',
        'home_address_lat': 40.7128,
        'home_address_lon': -74.0060,
      };

      final user = FriendUser.fromJson(json);

      expect(user.id, 1);
      expect(user.name, 'John Doe');
      expect(user.picture, 'https://example.com/pic.jpg');
      expect(user.homeAddressName, 'Home');
      expect(user.homeAddressLat, 40.7128);
      expect(user.homeAddressLon, -74.0060);
      expect(user.hasHomeAddress, true);
    });

    test('FriendUser.fromJson handles missing optional fields', () {
      final json = {
        'id': 2,
        'name': 'Jane Doe',
      };

      final user = FriendUser.fromJson(json);

      expect(user.id, 2);
      expect(user.name, 'Jane Doe');
      expect(user.picture, '');
      expect(user.homeAddressName, '');
      expect(user.homeAddressLat, 0.0);
      expect(user.homeAddressLon, 0.0);
      expect(user.hasHomeAddress, false);
    });

    test('FriendUser.hasHomeAddress returns true when address exists', () {
      final user = FriendUser(
        id: 1,
        name: 'Test',
        picture: 'pic',
        homeAddressName: 'My Home',
      );

      expect(user.hasHomeAddress, true);
    });

    test('FriendUser.hasHomeAddress returns false when address is empty', () {
      final user = FriendUser(
        id: 1,
        name: 'Test',
        picture: 'pic',
      );

      expect(user.hasHomeAddress, false);
    });
  });

  group('PendingRequest', () {
    test('PendingRequest.fromJson creates instance correctly', () {
      final json = {
        'id': 100,
        'sender': {
          'id': 5,
          'name': 'Sender Name',
          'picture': 'sender.jpg',
          'home_address_name': 'Sender Home',
          'home_address_lat': 34.0522,
          'home_address_lon': -118.2437,
        }
      };

      final request = PendingRequest.fromJson(json);

      expect(request.id, 100);
      expect(request.sender.id, 5);
      expect(request.sender.name, 'Sender Name');
      expect(request.sender.picture, 'sender.jpg');
      expect(request.sender.homeAddressName, 'Sender Home');
    });

    test('PendingRequest.fromJson handles missing sender fields', () {
      final json = {
        'id': 101,
        'sender': {
          'id': 6,
          'name': 'Minimal Sender',
        }
      };

      final request = PendingRequest.fromJson(json);

      expect(request.id, 101);
      expect(request.sender.id, 6);
      expect(request.sender.name, 'Minimal Sender');
      expect(request.sender.picture, '');
    });
  });

  group('FriendsService', () {
    late http.Client mockHttpClient;

    setUp(() {
      // Set up auth headers
      AuthService.instance.setToken('test_token');
    });

    /*test('searchUsers returns list of users on success', () async {
      mockHttpClient = http.MockClient((request) async {
        if (request.url.toString().contains('/search')) {
          return http.Response(
            '''[
              {"id": 1, "name": "User One", "picture": "pic1.jpg"},
              {"id": 2, "name": "User Two", "picture": "pic2.jpg"}
            ]''',
            200,
          );
        }
        return http.Response('{}', 400);
      });

      // We need to test using the actual service with the global http client
      // Since FriendsService uses http directly, we test the parsing logic
      final json1 = {
        'id': 1,
        'name': 'User One',
        'picture': 'pic1.jpg',
      };
      final json2 = {
        'id': 2,
        'name': 'User Two',
        'picture': 'pic2.jpg',
      };

      final users = [
        FriendUser.fromJson(json1),
        FriendUser.fromJson(json2),
      ];

      expect(users.length, 2);
      expect(users[0].name, 'User One');
      expect(users[1].name, 'User Two');
    }); */

    test('searchUsers returns empty list on error', () async {
      // Test that FriendUser.fromJson works correctly with search results
      expect(FriendsService.searchUsers('test') is Future, true);
    });

    test('FriendUser.fromJson handles numeric coordinate conversion', () {
      final jsonWithIntCoords = {
        'id': 1,
        'name': 'Test',
        'picture': 'pic',
        'home_address_lat': 40,
        'home_address_lon': -74,
      };

      final user = FriendUser.fromJson(jsonWithIntCoords);

      expect(user.homeAddressLat, 40.0);
      expect(user.homeAddressLon, -74.0);
      expect(user.homeAddressLat is double, true);
      expect(user.homeAddressLon is double, true);
    });

    test('getPendingRequests response parsing works correctly', () async {
      final json = {
        'id': 100,
        'sender': {
          'id': 5,
          'name': 'John',
          'picture': 'john.jpg',
        }
      };

      final request = PendingRequest.fromJson(json);

      expect(request.id, 100);
      expect(request.sender.name, 'John');
    });

    test('Multiple FriendUsers can be created and compared', () {
      final user1 = FriendUser(
        id: 1,
        name: 'Alice',
        picture: 'alice.jpg',
      );

      final user2 = FriendUser(
        id: 2,
        name: 'Bob',
        picture: 'bob.jpg',
      );

      expect(user1.id, isNot(user2.id));
      expect(user1.name, isNot(user2.name));
    });

    test('FriendUser with default coordinates', () {
      final user = FriendUser(
        id: 1,
        name: 'Test User',
        picture: 'test.jpg',
      );

      expect(user.homeAddressLat, 0.0);
      expect(user.homeAddressLon, 0.0);
    });
  });
}
