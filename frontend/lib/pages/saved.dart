import 'package:flutter/material.dart';

const Color kPurple = Color(0xFF63519F);

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});
  
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Center(
        child: Text(
          'Saved',
          style: TextStyle(
            color: kPurple,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

}