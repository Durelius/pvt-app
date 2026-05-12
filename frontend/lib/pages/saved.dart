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
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader(),
        ],
      ),
    );
  }

  
Widget _buildHeader() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 35, 16, 16),
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Center(
          child: Text(
            "Saved",
            style: TextStyle(
              color: Color(0xFF63519F),
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Align(
          alignment: Alignment.centerRight,
          child: Icon(
            Icons.bookmark_rounded,
            color: Color(0xFF63519F),
            size: 32,
          ),
        ),
      ],
    ),
  );
}


}