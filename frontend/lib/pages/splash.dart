import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/auth_service.dart';

const Color kPurple = Color(0xFF63519F);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _tryRestoreSession() {
    _sub = GoogleSignIn.instance.authenticationEvents.listen(
      (event) async {
        _timer?.cancel();
        _sub?.cancel();
        if (event is GoogleSignInAuthenticationEventSignIn) {
          await _handleSignIn(event.user);
        } else {
          _goToLogin();
        }
      },
      onError: (_) => _goToLogin(),
    );

    // Give the silent auth up to 3 seconds before giving up.
    _timer = Timer(const Duration(seconds: 3), _goToLogin);

    GoogleSignIn.instance.attemptLightweightAuthentication();
  }

  Future<void> _handleSignIn(GoogleSignInAccount user) async {
    final idToken = user.authentication.idToken;
    if (idToken == null) {
      _goToLogin();
      return;
    }

    AuthService.instance.setToken(idToken);

    try {
      final response = await http.post(
        Uri.parse('$apiBase/user/v1/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _navigateAfterLogin(response.body);
      } else {
        _goToLogin();
      }
    } catch (_) {
      if (mounted) _goToLogin();
    }
  }

  void _navigateAfterLogin(String responseBody) {
    if (!mounted) return;
    try {
      final user = jsonDecode(responseBody) as Map<String, dynamic>;
      final homeAddressName = (user['home_address_name'] as String?) ?? '';
      if (homeAddressName.isNotEmpty) {
        Hive.box('homeAddress').put('homeAddress', jsonEncode({
          'name': homeAddressName,
          'lat': user['home_address_lat'] ?? 0.0,
          'lon': user['home_address_lon'] ?? 0.0,
        }));
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        Navigator.of(context).pushReplacementNamed('/setup');
      }
    } catch (_) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  void _goToLogin() {
    _sub?.cancel();
    _timer?.cancel();
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MittenLogo(size: 200),
            SizedBox(height: 24),
            Text(
              'Mitten',
              style: TextStyle(
                color: kPurple,
                fontSize: 52,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MittenLogo extends StatelessWidget {
  final double size;
  const MittenLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/mitten_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
