import 'package:flutter_test/flutter_test.dart';
import 'package:mitten/services/auth_service.dart';

void main() {
  group('AuthService', () {
    setUp(() {
      AuthService.instance.clearToken();
    });

    test('singleton instance is identical', () {
      final firstInstance = AuthService.instance;
      final secondInstance = AuthService.instance;

      expect(identical(firstInstance, secondInstance), true);
    });

    test('isLoggedIn is false when no token is set', () {
      expect(AuthService.instance.isLoggedIn, false);
    });

    test('setToken marks the service as logged in', () {
      AuthService.instance.setToken('test-token');

      expect(AuthService.instance.isLoggedIn, true);
    });

    test('authHeaders contains JSON content type and bearer token', () {
      AuthService.instance.setToken('abc123');

      final headers = AuthService.instance.authHeaders;

      expect(headers['Content-Type'], 'application/json');
      expect(headers['Authorization'], 'Bearer abc123');
    });

    test('clearToken resets login state and token header value', () {
      AuthService.instance.setToken('abc123');
      AuthService.instance.clearToken();

      expect(AuthService.instance.isLoggedIn, false);
      expect(AuthService.instance.authHeaders['Authorization'], 'Bearer null');
    });
  });
}
