import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _goToMain(context);
            });
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
                      ? (GoogleSignIn.instance as dynamic).renderButton()
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

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final user = await GoogleSignIn.instance.authenticate();
      if (!context.mounted) return;

      final String? idToken = user.authentication.idToken;
      print('[login] idToken obtained: ${idToken != null}');

      final url = Uri.parse('$apiBase/user/v1/login');
      print('[login] POST $url');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );
      print('[login] response ${response.statusCode}: ${response.body}');
      if (response.statusCode == 200) {
        _goToMain(context);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error ${response.statusCode}')),
          );
        }
      }
    } on GoogleSignInException catch (e) {
      print('[login] GoogleSignInException: ${e.code} — ${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in error: ${e.description}')),
        );
      }
    } catch (e, stack) {
      print('[login] unexpected error: $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    }
  }

  void _continueAsGuest(BuildContext context) => _goToMain(context);

  void _goToMain(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/main');
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
