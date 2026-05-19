import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
    @override
    Widget build(BuildContext context) {
        return Scaffold(
          body: Padding(
            padding: EdgeInsets.all(15),
            child: Center(
              child: Column(
                children: [
                    Row(children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back))
                    ], ),
                    CircleAvatar(
                        backgroundColor: Color(0xFFEADDFF),
                        maxRadius: 75,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Icon(
                            Icons.person, 
                            color: Color(0xFF4F378A)) 
                        )
                    ),
                    SizedBox(height: 10),
                    Text('My Profile', style: TextStyle(color: Color(0xFF4F378A)),), //Subject to change
                    SizedBox(height: 40),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Color(0xFF6750A4)
                                )
                            ),
                            hintText: 'Your Address Here'
                        )
                      )
                    )
                ],
              ),
            )
          )
        );
    }
}