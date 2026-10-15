import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/data/task_repository.dart';
import 'package:task_manager/models/task.dart';
import 'package:task_manager/providers/task_provider.dart';

/// In-memory fake so business logic is tested without SQLite or a device.
class InMemoryTaskRepository implements TaskRepository {
  final List<Task> _store = [];
  int _nextId = 1;
  bool shouldFail = false;

  void _check() {
    if (shouldFail) throw StateError('storage failure');
  }

  @override
  Future<List<Task>> getAll() async {
    _check();
    return List.of(_store);
  }

  @override
  Future<Task> insert(Task task) async {
    _check();
    final saved = task.copyWith(id: _nextId++);
    _store.add(saved);
    return saved;
  }

  @override
  Future<void> update(Task task) async {
    _check();
    final i = _store.indexWhere((t) => t.id == task.id);
    _store[i] = task;
  }

  @override
  Future<void> delete(int id) async {
    _check();
    _store.removeWhere((t) => t.id == id);
  }
}

DateTime inDays(int n) {
  final t = dateOnly(DateTime.now());
  return DateTime(t.year, t.month, t.day + n);
}

List<String> titles(TaskProvider p) => p.visibleTasks.map((t) => t.title).toList();

void main() {
  late InMemoryTaskRepository repo;
  late TaskProvider provider;

  setUp(() {
    repo = InMemoryTaskRepository();
    provider = TaskProvider(repo);
  });

  /// Pay rent (day 1, pending), Buy tickets (day 2, completed),
  /// Buy groceries (day 3, pending).
  Future<void> seed() async {
    await provider.saveTask(Task(
      title: 'Buy groceries',
      description: 'Milk and eggs',
      dueDate: inDays(3),
    ));
    await provider.saveTask(Task(
      title: 'Pay rent',
      description: 'Transfer to landlord',
      dueDate: inDays(1),
      priority: TaskPriority.high,
    ));
    await provider.saveTask(Task(
      title: 'Buy tickets',
      description: 'Concert',
      dueDate: inDays(2),
    ));
    final tickets = provider.allTasks.firstWhere((t) => t.title == 'Buy tickets');
    await provider.toggleStatus(tickets);
  }

  group('add / edit / delete', () {
    test('adds a valid task and persists it', () async {
      final ok = await provider.saveTask(Task(
        title: '  Write report  ',
        description: 'Quarterly numbers',
        dueDate: inDays(2),
      ));

      expect(ok, isTrue);
      expect(provider.allTasks.single.title, 'Write report'); // trimmed
      expect(provider.allTasks.single.id, isNotNull);
      expect((await repo.getAll()).length, 1);
    });

    test('rejects empty title, empty description and past due date', () async {
      expect(
        await provider.saveTask(
            Task(title: '   ', description: 'x', dueDate: inDays(1))),
        isFalse,
      );
      expect(provider.error, 'Title is required');

      expect(
        await provider.saveTask(
            Task(title: 'Valid title', description: '', dueDate: inDays(1))),
        isFalse,
      );
      expect(provider.error, 'Description is required');

      expect(
        await provider.saveTask(
            Task(title: 'Valid title', description: 'x', dueDate: inDays(-1))),
        isFalse,
      );
      expect(provider.error, 'Due date cannot be in the past');

      expect(provider.allTasks, isEmpty);
      expect(await repo.getAll(), isEmpty);
    });

    test('edits an existing task in memory and in storage', () async {
      await seed();
      final rent = provider.allTasks.firstWhere((t) => t.title == 'Pay rent');

      final ok = await provider.saveTask(rent.copyWith(title: 'Pay electricity'));

      expect(ok, isTrue);
      expect(provider.totalCount, 3); // edited, not duplicated
      expect(
        (await repo.getAll()).map((t) => t.title),
        contains('Pay electricity'),
      );
    });

    test('deletes a task', () async {
      await seed();
      final rent = provider.allTasks.firstWhere((t) => t.title == 'Pay rent');

      expect(await provider.deleteTask(rent), isTrue);

      expect(provider.totalCount, 2);
      expect((await repo.getAll()).length, 2);
    });

    test('toggling status flips completed <-> pending and persists', () async {
      await provider.saveTask(
          Task(title: 'Toggle me', description: 'x', dueDate: inDays(1)));
      final task = provider.allTasks.single;

      await provider.toggleStatus(task);
      expect(provider.allTasks.single.isCompleted, isTrue);
      expect((await repo.getAll()).single.isCompleted, isTrue);

      await provider.toggleStatus(provider.allTasks.single);
      expect(provider.allTasks.single.isCompleted, isFalse);
    });
  });

  group('filter, search and sort', () {
    setUp(() async => seed());

    test('filter by status', () {
      provider.setFilter(TaskFilter.pending);
      expect(titles(provider), ['Pay rent', 'Buy groceries']);

      provider.setFilter(TaskFilter.completed);
      expect(titles(provider), ['Buy tickets']);

      provider.setFilter(TaskFilter.all);
      expect(provider.visibleTasks.length, 3);
    });

    test('search by title is case-insensitive', () {
      provider.setSearchQuery('RENT');
      expect(titles(provider), ['Pay rent']);

      provider.setSearchQuery('zzz');
      expect(provider.visibleTasks, isEmpty);
    });

    test('filter and search work together', () {
      provider.setSearchQuery('buy');
      expect(titles(provider), ['Buy tickets', 'Buy groceries']);

      provider.setFilter(TaskFilter.completed);
      expect(titles(provider), ['Buy tickets']);

      provider.setFilter(TaskFilter.pending);
      expect(titles(provider), ['Buy groceries']);
    });

    test('sorts by due date, ascending and descending', () {
      expect(titles(provider), ['Pay rent', 'Buy tickets', 'Buy groceries']);

      provider.toggleSortDirection();
      expect(titles(provider), ['Buy groceries', 'Buy tickets', 'Pay rent']);
    });

    test('summary counts ignore filter and search', () {
      provider.setFilter(TaskFilter.completed);
      provider.setSearchQuery('rent');

      expect(provider.totalCount, 3);
      expect(provider.pendingCount, 2);
      expect(provider.completedCount, 1);
    });
  });

  group('persistence and error handling', () {
    test('tasks survive an app restart (new provider, same storage)', () async {
      await seed();

      final restarted = TaskProvider(repo);
      await restarted.load();

      expect(restarted.totalCount, 3);
      expect(restarted.completedCount, 1);
    });

    test('storage failure on save keeps state and reports an error', () async {
      repo.shouldFail = true;

      final ok = await provider.saveTask(
          Task(title: 'Will fail', description: 'x', dueDate: inDays(1)));

      expect(ok, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.allTasks, isEmpty);
    });

    test('storage failure on load does not throw', () async {
      repo.shouldFail = true;

      await provider.load();

      expect(provider.error, isNotNull);
      expect(provider.isLoading, isFalse);
    });
  });

  group('TaskValidators', () {
    test('title rules', () {
      expect(TaskValidators.title(null), isNotNull);
      expect(TaskValidators.title('ab'), isNotNull);
      expect(TaskValidators.title('a' * 101), isNotNull);
      expect(TaskValidators.title('Good title'), isNull);
    });

    test('Task <-> map round trip keeps all fields', () {
      final task = Task(
        id: 7,
        title: 'Round trip',
        description: 'desc',
        dueDate: inDays(5),
        isCompleted: true,
        priority: TaskPriority.high,
      );
      final copy = Task.fromMap(task.toMap());

      expect(copy.id, 7);
      expect(copy.title, 'Round trip');
      expect(copy.dueDate, task.dueDate);
      expect(copy.isCompleted, isTrue);
      expect(copy.priority, TaskPriority.high);
    });
  });
}
