import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../services/auth_service.dart';
import '../google_sign_in_button_stub.dart'
    if (dart.library.html) '../google_sign_in_button_web.dart';
import 'splash.dart' show kPurple, MittenLogo;

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<GoogleSignInAuthenticationEvent>(
        stream: GoogleSignIn.instance.authenticationEvents,
        builder: (context, snapshot) {
          if (snapshot.hasData &&
              snapshot.data is GoogleSignInAuthenticationEventSignIn) {
            final event = snapshot.data as GoogleSignInAuthenticationEventSignIn;
            if (kIsWeb) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleWebSignIn(context, event.user);
              });
            }
            // Native: button handler (_signInWithGoogle) drives all post-login navigation.
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MittenLogo(size: 110),
                  const SizedBox(height: 20),
                  const Text(
                    'Mitten',
                    style: TextStyle(
                      color: kPurple,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 52),
                  kIsWeb
                      ? googleSignInWebButton()
                      : _GoogleSignInButton(
                          onPressed: () => _signInWithGoogle(context),
                        ),
                  const SizedBox(height: 12),
                  _GuestButton(onPressed: () => _continueAsGuest(context)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Web: sign-in came from renderButton() — extract token and register with backend.
  Future<void> _handleWebSignIn(
      BuildContext context, GoogleSignInAccount user) async {
    final idToken = user.authentication.idToken;
    if (idToken != null) AuthService.instance.setToken(idToken);

    try {
      final response = await http.post(
        Uri.parse('$apiBase/user/v1/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        _navigateAfterLogin(context, response.body);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    }
  }

  // Native: authenticate() triggers the Google sign-in flow.
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final user = await GoogleSignIn.instance.authenticate();
      if (!context.mounted) return;

      final String? idToken = user.authentication.idToken;
      if (idToken != null) AuthService.instance.setToken(idToken);

      final response = await http.post(
        Uri.parse('$apiBase/user/v1/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        _navigateAfterLogin(context, response.body);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error ${response.statusCode}')),
        );
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in error: ${e.description}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    }
  }

  void _navigateAfterLogin(BuildContext context, String responseBody) {
    if (!context.mounted) return;
    try {
      final user = jsonDecode(responseBody) as Map<String, dynamic>;

      Hive.box('userProfile').put('name', (user['name'] as String?) ?? '');
      Hive.box('userProfile').put('picture', (user['picture'] as String?) ?? '');

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

  void _continueAsGuest(BuildContext context) {
    if (context.mounted) Navigator.of(context).pushReplacementNamed('/main');
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFFDADADA)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: Colors.white,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'G',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDB4437),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Sign in with Google',
              style: TextStyle(
                color: Color(0xFF444444),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GuestButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Color(0xFFDADADA)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          backgroundColor: const Color(0xFFF5F5F5),
        ),
        child: const Text(
          'Continue as guest',
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
