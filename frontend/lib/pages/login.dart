import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'splash.dart' show kPurple, MittenLogo;

//Imports for google sign in and location services
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mitten/services/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: StreamBuilder<GoogleSignInAccount?>(
      // We listen to the global instance we set up in auth_provider.dart
      stream: googleSignIn.onCurrentUserChanged,
      builder: (context, snapshot) {
        // As soon as the stream emits a user (from the web button click)
        if (snapshot.hasData && snapshot.data != null) {
          // Use addPostFrameCallback to avoid "Building while navigating" errors
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
                ? (GoogleSignInPlatform.instance as dynamic).renderButton()
                : _GoogleSignInButton(onPressed: () => _signInWithGoogle(context)),
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
      final user = await googleSignIn.signIn();
      if (user != null && context.mounted) {
        final auth = await user.authentication;
        final String? idToken = auth.idToken;
        print("Login successful! Here is your token: $idToken");

        final url = Uri.parse('$apiBase/googlesigninverification/v1/verify-google-signin');
        final response = await http.post(url,headers: {'Content-Type': 'application/json'},body: jsonEncode({'id_token': idToken}),);
        if (response.statusCode == 200) {
          print('Login successful: ${response.body}');
          _goToMain(context);
        } else {
          print('Verification failed with status: ${response.statusCode}');
        }

        
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in failed. Please try again.')),
        );
      }
    }
  }

  void _continueAsGuest(BuildContext context) => _goToMain(context);

  void _goToMain(BuildContext context) {
    // Pop everything and go to main — main.dart handles pushing MyHomePage
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
