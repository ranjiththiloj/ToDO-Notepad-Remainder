import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

enum TodoSection { None, Gym, Study }

class TodoItem {
  final String task;
  final DateTime createdDate;
  bool completed;
  TodoSection section;

  TodoItem({
    required this.task,
    required this.createdDate,
    this.completed = false,
    this.section = TodoSection.None,
  });

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'createdDate': createdDate.toIso8601String(),
      'completed': completed,
      'section': section.toString().split('.').last,
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      task: json['task'],
      createdDate: DateTime.parse(json['createdDate']),
      completed: json['completed'],
      section: TodoSection.values.firstWhere((e) => e.toString().split('.').last == json['section']),
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _controller = TextEditingController();
  final List<TodoItem> _todoItems = [];
  List<String> _sections = ['None', 'Gym', 'Study'];
  TodoSection _selectedSection = TodoSection.None;

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
    List<String>? todoList = prefs.getStringList('todo_list');
    if (todoList != null) {
      setState(() {
        _todoItems.clear();
        _todoItems.addAll(todoList.map((json) => TodoItem.fromJson(jsonDecode(json))));
      });
    }
  }

  void _saveTodoItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> todoList = _todoItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList('todo_list', todoList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Todo List'),
      ),
      body: Column(
        children: [
          _buildSectionBar(),
          Expanded(
            child: _buildTaskList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddTodoDialog(context);
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionBar() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final section = _sections[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSection = TodoSection.values[index]; // Skip None
              });
            },
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              margin: EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(20.0),
                color: _selectedSection == TodoSection.values[index]
                    ? Colors.blue // Highlight selected section
                    : null,
              ),
              child: Text(
                section,
                style: TextStyle(
                  color: _selectedSection == TodoSection.values[index]
                      ? Colors.white // Text color when selected
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskList() {
    final tasksForSelectedSection = _todoItems.where((item) => item.section == _selectedSection).toList();
    return ListView.builder(
      itemCount: tasksForSelectedSection.length,
      itemBuilder: (context, index) {
        final todoItem = tasksForSelectedSection[index];
        return ListTile(
          title: Text(
            todoItem.task,
            style: TextStyle(fontSize: 18.0),
          ),
          subtitle: Text(
            DateFormat('EEEE, MMM d').format(todoItem.createdDate),
            style: TextStyle(fontSize: 14.0, color: Colors.grey),
          ),
          trailing: GestureDetector(
            onTap: () {
              setState(() {
                todoItem.completed = !todoItem.completed;
                _saveTodoItems();
                _animationController.forward(from: 0);
              });
            },
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.5).animate(_animationController),
              child: Icon(
                Icons.check_circle,
                color: todoItem.completed ? Colors.green : Colors.grey,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Todo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selected Section: ${_selectedSection.toString().split('.').last}'),
              SizedBox(height: 8.0),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Enter task',
                ),
              ),
            ],
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
                if (task.isNotEmpty && _selectedSection != TodoSection.None) {
                  setState(() {
                    _todoItems.add(TodoItem(
                      task: task,
                      createdDate: DateTime.now(),
                      section: _selectedSection,
                    ));
                    _saveTodoItems();
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
