import 'package:flutter/material.dart';

class PlanPage extends StatefulWidget{
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final TextEditingController _controller = TextEditingController();

  //addresses stored
  final List<String> _items = [];

  void _addItem(){
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _items.add(_controller.text.trim());
      _controller.clear();
    });
  }
@override
  Widget build(BuildContext context){
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller, decoration: const InputDecoration(hintText: 'Address:', border: OutlineInputBorder(),),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addItem,
              ),
            ],),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(_items[index]),
            ),
          ),
        ),
      ],
    );
  }
}