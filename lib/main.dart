import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';

// Global database reference
late Database database;

class Task {
  final int? id;
  final String label;
  final bool isDone;
  final String description;

  const Task({
    this.id,
    required this.label,
    this.isDone = false,
    this.description = '',
  });

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      label: map['label'] as String? ?? '',
      isDone: _sqliteBool(map['isDone']),
    );
  }

  static bool _sqliteBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalizedValue = value.toLowerCase();
      return normalizedValue == '1' || normalizedValue == 'true';
    }
    return false;
  }

  Map<String, Object?> toMap() {
    return {
      'label': label,
      'isDone': isDone ? 1 : 0, // SQLite uses 0/1 for booleans
      if (id != null) 'id': id,
    };
  }

  Task copyWith({int? id, String? label, bool? isDone, String? description}) {
    return Task(
      id: id ?? this.id,
      label: label ?? this.label,
      isDone: isDone ?? this.isDone,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'Task{id: $id, label: $label, isDone: $isDone,description: $description}';
  }
}

Future<void> insertTask(Task task) async {
  await database.insert('tasks', task.toMap());
}

Future<List<Task>> tasks() async {
  final List<Map<String, Object?>> taskMaps = await database.query('tasks');
  return [
    for (final map in taskMaps)
      Task(id: map['id'] as int, label: map['label'] as String),
  ];
}

Future<void> updateTask(Task task) async {
  final id = task.id;
  if (id == null) {
    throw ArgumentError('Task id is required for updates.');
  }

  await database.update(
    'tasks',
    task.toMap(),
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> deleteTask(int id) async {
  await database.delete('tasks', where: 'id = ?', whereArgs: [id]);
}

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Navigation());
  }
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
    version: 2,
  );

  runApp(const NavigationBarApp());
}

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _ToDoListState();
}

class _ToDoListState extends State<Navigation> {
  int currentPageIndex = 0;
  final TextEditingController _taskController = TextEditingController();
  Task? _editingTask;
  List<Task> _taskList = [];

  @override
  void initState() {
    super.initState();
    _taskController.addListener(() => setState(() {}));
    _loadTasks();
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final list = await tasks();
    setState(() {
      print(list);
      _taskList = list;
    });
  }

  Future<void> _toggleTask(Task task, bool isDone) async {
    await updateTask(task.copyWith(isDone: isDone));
    await _loadTasks();
  }

  Future<void> _submitTask() async {
    final trimmedTask = _taskController.text.trim();
    if (trimmedTask.isEmpty) {
      return;
    }

    final editing = _editingTask;
    if (editing != null) {
      await updateTask(editing.copyWith(label: trimmedTask));
    } else {
      await insertTask(Task(label: trimmedTask, isDone: false));
    }

    _taskController.clear();
    setState(() {
      _editingTask = null;
    });
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    // final completedTasks = _taskList.where((task) => task.isDone).toList();

    final navigationBarWidget = NavigationBar(
      onDestinationSelected: (int index) {
        setState(() {
          currentPageIndex = index;
        });

        _taskController.clear();
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
          icon: Badge(child: Icon(Icons.remove_red_eye_outlined)),
          label: 'Preview',
        ),
      ],
    );

    final homePageWidget = Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
      child: Card(
        shadowColor: Colors.transparent,
        child: SizedBox.expand(
          child: Column(
            children: [
              TextField(
                autofocus: true,
                controller: _taskController,
                decoration: const InputDecoration(
                  labelText: 'Add description',
                  hintText: 'Enter your task here',
                  border: UnderlineInputBorder(),
                ),
                onSubmitted: (_) => _submitTask(),
              ),
              TextField(
                autofocus: true,
                controller: _taskController,
                decoration: const InputDecoration(
                  labelText: 'Add task',
                  hintText: 'Enter your task here',
                  border: UnderlineInputBorder(),
                ),
                onSubmitted: (_) => _submitTask(),
              ),
              ElevatedButton.icon(
                icon: Icon(_editingTask == null ? Icons.add : Icons.save),
                onPressed: () async {
                  _taskController.text.trim().isEmpty ? null : _submitTask();

                  currentPageIndex = 1;
                },
                label: Text(_editingTask == null ? 'Add Task' : 'Update Task'),
              ),
            ],
          ),
        ),
      ),
    );

    final taskListWidget = _taskList.isEmpty
        ? const Center(child: Text('No tasks yet'))
        : Container(
            padding: const EdgeInsets.all(10.0),
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _taskList.length,
              itemBuilder: (context, index) {
                final task = _taskList[index];
                return Card(
                  child: CheckboxListTile(
                    value: task.isDone,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      await _toggleTask(task, value);
                    },
                    title: Text(task.label),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: !task.isDone
                          ? [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  _taskController.text = task.label;
                                  setState(() {
                                    _editingTask = task;
                                    currentPageIndex = 0;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  deleteTask(
                                    task.id!,
                                  ).then((_) => _loadTasks());
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye),
                                onPressed: () {
                                  _taskController.text = task.label;
                                  setState(() {
                                    currentPageIndex = 2;
                                  });
                                },
                              ),
                            ]
                          : [
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye),
                                onPressed: null,
                              ),
                            ],
                    ),
                  ),
                );
              },
            ),
          );

    final completedTasksWidget = Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      width: 500,
      child: Column(
        children: [
          Image.network('https://picsum.photos/200/300?grayscale'),
          Text(
            _taskController.text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              height: 3,
            ),
          ),
          Text(
            'subtitle subtitle subtitle',
            style: TextStyle(
              fontSize: 15,
              color: Color.fromRGBO(125, 125, 125, 80),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      bottomNavigationBar: navigationBarWidget,

      body: <Widget>[
        homePageWidget,
        taskListWidget,
        completedTasksWidget,
      ][currentPageIndex],
    );
  }
}
