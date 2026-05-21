class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String? _idToken;

  bool get isLoggedIn => _idToken != null;

  void setToken(String token) => _idToken = token;

  void clearToken() => _idToken = null;

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_idToken',
      };
}
