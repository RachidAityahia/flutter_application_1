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

  const Task({this.id, required this.label, this.isDone = false});

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

  Task copyWith({int? id, String? label, bool? isDone}) {
    return Task(
      id: id ?? this.id,
      label: label ?? this.label,
      isDone: isDone ?? this.isDone,
    );
  }

  @override
  String toString() {
    return 'Task{id: $id, label: $label, isDone: $isDone}';
  }
}

Future<void> insertTask(Task task) async {
  await database.insert(
    'tasks',
    task.toMap(),
  );
}

Future<List<Task>> tasks() async {
  final List<Map<String, Object?>> taskMaps = await database.query('tasks');
  return [for (final map in taskMaps) Task.fromMap(map)];
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  database = await openDatabase(
    join(await getDatabasesPath(), 'task_database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, label TEXT, isDone INTEGER)',
      );
    },
    version: 2, // Bumped version to add isDone column
  );

  runApp(const NavigationBarApp());
}

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: Navigation());
  }
}

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _ToDoListState();
}

class _ToDoListState extends State<Navigation> {
  int currentPageIndex = 0;
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

  Future<void> _toggleTask(Task task, bool isDone) async {
    await updateTask(task.copyWith(isDone: isDone));
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    final completedTasks = _taskList.where((task) => task.isDone).toList();

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
                    final trimmedTask = taskText.trim();
                    if (trimmedTask.isEmpty) {
                      return;
                    }

                    final task = Task(label: trimmedTask, isDone: false);
                    await insertTask(task);
                    taskText = '';

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
                    child: CheckboxListTile(
                      value: task.isDone,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) async {
                        if (value == null) {
                          return;
                        }
                        await _toggleTask(task, value);
                      },
                      title: Text(
                        task.label,
                      ),
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children:
                        !task.isDone
                            ? [IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  setState(() {
                                    taskText = task.label;
                                    currentPageIndex = 0;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    deleteTask(task.id!).then((_) => _loadTasks());
                                  });
                                },
                              ),
                            ]
                            :[],
                      ),
                    ),
                  );
                },
              ),

        /// Done Tasks page
        completedTasks.isEmpty
            ? const Center(child: Text('No completed tasks yet'))
            : ListView.builder(
                itemCount: completedTasks.length,
                itemBuilder: (context, index) {
                  final task = completedTasks[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.done_outline_sharp),
                      title: Text(
                        task.label,
                        style: const TextStyle(
                          // color: Color(0x6A60CD26)
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
