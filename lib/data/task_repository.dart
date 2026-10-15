import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

/// Storage contract. The provider depends on this abstraction, not on SQLite,
/// so tests can swap in an in-memory fake.
abstract class TaskRepository {
  Future<List<Task>> getAll();
  Future<Task> insert(Task task);
  Future<void> update(Task task);
  Future<void> delete(int id);
}

class SqliteTaskRepository implements TaskRepository {
  static const _table = 'tasks';

  // `late final` with an initializer is lazy: the DB opens once, on first use.
  late final Future<Database> _db = _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'tasks.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $_table (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          due_date INTEGER NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          priority INTEGER NOT NULL DEFAULT 1
        )
      '''),
    );
  }

  @override
  Future<List<Task>> getAll() async {
    final db = await _db;
    final rows = await db.query(_table);
    return rows.map(Task.fromMap).toList();
  }

  @override
  Future<Task> insert(Task task) async {
    final db = await _db;
    final id = await db.insert(_table, task.toMap());
    return task.copyWith(id: id);
  }

  @override
  Future<void> update(Task task) async {
    final db = await _db;
    await db.update(_table, task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  @override
  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
