import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('Task.toMap omits id for new tasks', () {
    final task = Task(label: 'Write regression test');

    expect(task.toMap(), {'label': 'Write regression test', 'is_done': 0});
  });

  test('Task.toMap includes id for persisted tasks', () {
    final task = Task(id: 7, label: 'Existing task', isDone: true);

    expect(task.toMap(), {'label': 'Existing task', 'is_done': 1, 'id': 7});
  });

  test('Task.fromMap converts sqlite completion flag to bool', () {
    final task = Task.fromMap({
      'id': 3,
      'label': 'Checked task',
      'is_done': 1,
    });

    expect(task.id, 3);
    expect(task.label, 'Checked task');
    expect(task.isDone, isTrue);
  });
}
