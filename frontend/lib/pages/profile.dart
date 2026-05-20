import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
    final FocusNode _focusNode = FocusNode();
    final TextEditingController _textFieldController = TextEditingController();
    final homeAddressBox = Hive.box('homeAddress');
    Color _fillColor = Color(0xFFE8DEF8);

    @override
    void initState() {
      super.initState();

      final homeAddressText = homeAddressBox.get('homeAddress');

      if(homeAddressText != null) {
        _textFieldController.text = homeAddressText;
      }

      _focusNode.addListener(() {
        setState(() {
          _fillColor = _focusNode.hasFocus ? Color(0xFFF4EFF6) : Color(0xFFE8DEF8);
        });

        if(!_focusNode.hasFocus) {
            homeAddressBox.put('homeAddress', _textFieldController.text);
        }
      });
    }

    @override
    void dispose() {
      _focusNode.dispose();
      _textFieldController.dispose();
      super.dispose();
    }

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
                        focusNode: _focusNode,
                        controller: _textFieldController,
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: _fillColor,
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Color(0xFFE8DEF8),
                                    width: 2
                                )
                            ),
                            focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Color(0xFF6750A4),
                                    width: 2
                                )
                            ),
                            hintText: 'Your Address Here',
                            hintStyle: TextStyle(color: Color(0xFF6750A4))
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