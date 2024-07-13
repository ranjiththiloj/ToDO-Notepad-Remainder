import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ReminderPage(),
    );
  }
}

class ReminderPage extends StatefulWidget {
  @override
  _ReminderListPageState createState() => _ReminderListPageState();
}

class _ReminderListPageState extends State<ReminderPage> {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> _reminders = [];

  @override
  void initState() {
    super.initState();
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? remindersString = prefs.getString('reminders');
    if (remindersString != null) {
      setState(() {
        _reminders = List<Map<String, dynamic>>.from(json.decode(remindersString));
      });
    }
  }

  Future<void> _saveReminders() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('reminders', json.encode(_reminders));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reminders'),
      ),
      body: _reminders.isEmpty
          ? Center(child: Text('No reminders yet!'))
          : ListView.builder(
        itemCount: _reminders.length,
        itemBuilder: (context, index) {
          final reminder = _reminders[index];
          return ListTile(
            title: Text(reminder['task']),
            subtitle: Text(DateFormat('yyyy-MM-dd HH:mm')
                .format(DateTime.parse(reminder['dateTime']))),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddReminderDialog(context),
        child: Icon(Icons.add),
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddReminderDialog(
          onAdd: (task, dateTime) {
            setState(() {
              _reminders.add({
                'task': task,
                'dateTime': dateTime.toIso8601String(),
              });
            });
            _saveReminders();
            _scheduleNotification(task, dateTime);
          },
        );
      },
    );
  }

  Future<void> _scheduleNotification(String task, DateTime scheduledNotificationDateTime) async {
    var androidDetails = const AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      importance: Importance.max,
      priority: Priority.high,
    );
    var generalNotificationDetails =
    NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Reminder',
      task,
      tz.TZDateTime.from(scheduledNotificationDateTime, tz.local),
      generalNotificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

class AddReminderDialog extends StatefulWidget {
  final Function(String task, DateTime dateTime) onAdd;

  AddReminderDialog({required this.onAdd});

  @override
  _AddReminderDialogState createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  DateTime? _selectedDateTime;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Reminder'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _taskController,
              decoration: InputDecoration(labelText: 'Task'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a task';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDateTime == null
                        ? 'No date chosen!'
                        : DateFormat('yyyy-MM-dd HH:mm')
                        .format(_selectedDateTime!),
                  ),
                ),
                TextButton(
                  onPressed: () => _selectDateTime(context),
                  child: Text('Choose Date & Time'),
                ),
              ],
            ),
          ],
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
            if (_formKey.currentState!.validate() &&
                _selectedDateTime != null) {
              widget.onAdd(_taskController.text, _selectedDateTime!);
              Navigator.of(context).pop();
            }
          },
          child: Text('Add'),
        ),
      ],
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }
}
