import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  test('Task.toMap omits id for new tasks', () {
    final task = Task(label: 'Write regression test');

    expect(task.toMap(), {'label': 'Write regression test'});
  });

  test('Task.toMap includes id for persisted tasks', () {
    final task = Task(id: 7, label: 'Existing task');

    expect(task.toMap(), {'label': 'Existing task', 'id': 7});
  });
}
