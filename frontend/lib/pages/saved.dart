import 'package:flutter/material.dart';

const Color kPurple = Color(0xFF63519F);
const Color kBackGroundWhite = Color(0xFFF5F5F5);
const Color kBrightPurple = Color(0xFFEADDFF);


class FakeGroup {
  final String name;
  final IconData icon;

  FakeGroup({required this.name, required this.icon});
}


class SavedPage extends StatefulWidget {
  const SavedPage({super.key});
  
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {

  
  final List<FakeGroup> _groups = [
    FakeGroup(name: "My First Group", icon: Icons.group_rounded),
    FakeGroup(name: "Placeholder", icon: Icons.group_rounded),
    FakeGroup(name: "Trip Plan", icon: Icons.group_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackGroundWhite,
      body: Column(
        children: [
          _buildHeader(),
          _buildGroupsSection(),
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
                color: kPurple,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.bookmark_rounded,
              color: kPurple,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "My Groups",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: kPurple,
            ),
          ),
        ),

        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            itemCount: _groups.length,
            itemBuilder: (context, index) {
              final group = _groups[index];

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildGroupCard(group),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(FakeGroup group) {
  return GestureDetector(
    onTap: () {},
    child: AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: kPurple,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              group.icon,
              color: kBrightPurple,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              group.name,
              style: const TextStyle(
                color: kBrightPurple,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    )
  );
}



}