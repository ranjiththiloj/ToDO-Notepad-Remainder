import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class Note {
  final String task;
  final DateTime createdDate;

  Note({required this.task, required this.createdDate});

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'createdDate': createdDate.toIso8601String(),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      task: json['task'],
      createdDate: DateTime.parse(json['createdDate']),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note Pad',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: NotePadScreen(),
    );
  }
}

class NotePadScreen extends StatefulWidget {
  @override
  _NotePadScreenState createState() => _NotePadScreenState();
}

class _NotePadScreenState extends State<NotePadScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _controller = TextEditingController();
  final List<Note> _noteItems = [];

  @override
  void initState() {
    super.initState();
    _loadTodoItems();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadTodoItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? todoList = prefs.getStringList('note_pad');
    if (todoList != null) {
      setState(() {
        _noteItems.clear();
        _noteItems.addAll(todoList.map((json) => Note.fromJson(jsonDecode(json))));
      });
    }
  }

  void _saveNotePadItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> notePad = _noteItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('note_pad', notePad);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NotePad'),
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          child: ListView.builder(
            itemCount: _noteItems.length,
            itemBuilder: (context, index) {
              final todoItem = _noteItems[index];
              return Dismissible(
                key: Key(todoItem.task),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 20.0),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Confirm Delete'),
                        content: Text('Are you sure you want to delete this todo?'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(false);
                            },
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(true);
                            },
                            child: Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  setState(() {
                    _noteItems.removeAt(index);
                    _saveNotePadItems();
                  });
                },
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          padding: EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                todoItem.task,
                                style: TextStyle(fontSize: 18.0),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.0),
                              Text(
                                DateFormat('EEEE, MMM d').format(todoItem.createdDate),
                                style: TextStyle(fontSize: 14.0, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8.0), // Add some space between boxes
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddTodoDialog(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Note'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Enter task',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final task = _controller.text.trim();
                if (task.isNotEmpty) {
                  setState(() {
                    _noteItems.add(Note(task: task, createdDate: DateTime.now()));
                    _saveNotePadItems();
                  });
                  _controller.clear();
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
