import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

// Global database reference
late Database database;

class Task {
  final int id;
  final String label;

  Task({required this.id, required this.label});

  Map<String, Object?> toMap() {
    return {'id': id, 'label': label};
  }

  @override
  String toString() {
    return 'Task{id: $id, label: $label}';
  }
}

Future<void> insertTask(Task task) async {
  await database.insert(
    'tasks',
    task.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<List<Task>> tasks() async {
  final List<Map<String, Object?>> taskMaps = await database.query('tasks');
  return [
    for (final map in taskMaps)
      Task(id: map['id'] as int, label: map['label'] as String),
  ];
}

Future<void> updateTask(Task task) async {
  await database.update(
    'tasks',
    task.toMap(),
    where: 'id = ?',
    whereArgs: [task.id],
  );
}

Future<void> deleteTask(int id) async {
  await database.delete('tasks', where: 'id = ?', whereArgs: [id]);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  database = await openDatabase(
    join(await getDatabasesPath(), 'task_database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, label TEXT)',
      );
    },
    version: 1,
  );

  runApp(const NavigationBarApp());
}

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: NavigationExample());
  }
}

class NavigationExample extends StatefulWidget {
  const NavigationExample({super.key});

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationExample> {
  int currentPageIndex = 0;
  bool light = false;
  var taskText = '';
  List<Task> _taskList = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final list = await tasks();
    setState(() {
      _taskList = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: const Color.fromARGB(255, 193, 178, 233),
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(child: Icon(Icons.list_alt_sharp)),
            label: 'Task List',
          ),
          NavigationDestination(
            icon: Badge(child: Icon(Icons.done_outline_sharp)),
            label: 'Done Tasks',
          ),
        ],
      ),
      body: <Widget>[
        /// Home page
        Card(
          shadowColor: Colors.transparent,
          margin: const EdgeInsets.all(8.0),
          child: SizedBox.expand(
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Add task',
                    hintText: 'Enter your task here',
                    border: UnderlineInputBorder(),
                  ),
                  onChanged: (text) {
                    taskText = text;
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  onPressed: () async {
                    final task = Task(id: 0, label: taskText);
                    await insertTask(task);
                    await _loadTasks();
                  },
                  label: Text('Add Task'),
                ),
              ],
            ),
          ),
        ),

        /// Task List page
        _taskList.isEmpty
            ? const Center(child: Text('No tasks yet'))
            : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _taskList.length,
                itemBuilder: (context, index) {
                  final task = _taskList[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.list_alt_sharp),
                      title: Text(task.label),
                    ),
                  );
                },
              ),

        /// Messages page
        ListView.builder(
          reverse: true,
          itemCount: 2,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.all(8.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    'Hello',
                    style: theme.textTheme.bodyLarge!.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              );
            }
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  'Hi!',
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            );
          },
        ),
      ][currentPageIndex],
    );
  }
}
