import 'package:flutter/material.dart';
import 'login.dart';

const Color kPurple = Color(0xFF63519F);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MittenLogo(size: 200),
            const SizedBox(height: 24),
            const Text(
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
      'assets/mitten.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
