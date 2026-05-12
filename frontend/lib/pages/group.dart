import 'package:flutter/material.dart';
import 'saved.dart';

const Color kYellow = Color(0xFFFFDC00);

class GroupPage extends StatelessWidget {
  final FakeGroup group;

  const GroupPage({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackGroundWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          group.name,
          style: TextStyle(
            color: kPurple,
            fontSize: 28,
            fontWeight: FontWeight.w400
          ),
        ),
        
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          _buildGroupIcon(),
          const SizedBox(height: 60),
          _buildMiddleButton(),
          const SizedBox(height: 40),
        ]
      ),
    );
  }

  Widget _buildGroupIcon(){
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: const BoxDecoration(
          color: kPurple,
          shape: BoxShape.circle,
        ),
        child: Icon(
          group.icon,
          size: 120,
          color: kBrightPurple 
        ),
      ),
    );
  }

  Widget _buildMiddleButton()
  {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        
        height: 100,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: kPurple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(70),
            ),
            elevation: 8
          ),
          child: const Text(
            "View middle point",
            style: TextStyle(
              color: kYellow,
              fontSize: 28,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

}