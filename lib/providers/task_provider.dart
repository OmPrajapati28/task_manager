import 'package:flutter/foundation.dart';

import '../data/task_repository.dart';
import '../models/task.dart';

/// Holds task state and all business logic (CRUD, filter, search, sort, summary).
/// Widgets only read from it and call its methods.
class TaskProvider extends ChangeNotifier {
  TaskProvider(this._repository);

  final TaskRepository _repository;

  List<Task> _tasks = [];
  TaskFilter _filter = TaskFilter.all;
  String _query = '';
  bool _sortAscending = true; // sort by due date
  bool _isLoading = false;
  String? _error;

  // ---- read-only state exposed to the UI ----
  List<Task> get allTasks => List.unmodifiable(_tasks);
  TaskFilter get filter => _filter;
  String get query => _query;
  bool get sortAscending => _sortAscending;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasTasks => _tasks.isNotEmpty;

  // ---- summary (always over ALL tasks, ignoring filter/search) ----
  int get totalCount => _tasks.length;
  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get pendingCount => totalCount - completedCount;

  /// Filter + search are applied together, then sorted by due date
  /// (ties: higher priority first).
  List<Task> get visibleTasks {
    final q = _query.trim().toLowerCase();
    final result = _tasks.where((t) {
      final matchesFilter = switch (_filter) {
        TaskFilter.all => true,
        TaskFilter.pending => !t.isCompleted,
        TaskFilter.completed => t.isCompleted,
      };
      final matchesSearch = q.isEmpty || t.title.toLowerCase().contains(q);
      return matchesFilter && matchesSearch;
    }).toList();

    result.sort((a, b) {
      final byDate = _sortAscending
          ? a.dueDate.compareTo(b.dueDate)
          : b.dueDate.compareTo(a.dueDate);
      if (byDate != 0) return byDate;
      return b.priority.index.compareTo(a.priority.index);
    });
    return result;
  }

  // ---- UI state changes ----
  void setFilter(TaskFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void toggleSortDirection() {
    _sortAscending = !_sortAscending;
    notifyListeners();
  }

  // ---- persistence-backed actions ----
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tasks = await _repository.getAll();
    } catch (_) {
      _error = 'Could not load tasks. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds the task when `id == null`, otherwise updates it.
  /// Returns false (and sets [error]) on invalid data or a storage failure.
  Future<bool> saveTask(Task task) async {
    final problem = TaskValidators.title(task.title) ??
        TaskValidators.description(task.description) ??
        TaskValidators.dueDate(task.dueDate, allowPast: task.id != null);
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return false;
    }

    final clean = task.copyWith(
      title: task.title.trim(),
      description: task.description.trim(),
      dueDate: dateOnly(task.dueDate),
    );

    return _guard('Could not save the task. Please try again.', () async {
      if (clean.id == null) {
        final saved = await _repository.insert(clean);
        _tasks = [..._tasks, saved];
      } else {
        await _repository.update(clean);
        _tasks = [for (final t in _tasks) t.id == clean.id ? clean : t];
      }
    });
  }

  Future<bool> toggleStatus(Task task) {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    return _guard('Could not update the task. Please try again.', () async {
      await _repository.update(updated);
      _tasks = [for (final t in _tasks) t.id == updated.id ? updated : t];
    });
  }

  Future<bool> deleteTask(Task task) {
    return _guard('Could not delete the task. Please try again.', () async {
      await _repository.delete(task.id!);
      _tasks = _tasks.where((t) => t.id != task.id).toList();
    });
  }

  /// Runs a storage action; on failure keeps the old state and records an error
  /// instead of letting the exception crash the app.
  Future<bool> _guard(String errorMessage, Future<void> Function() action) async {
    try {
      await action();
      _error = null;
      notifyListeners();
      return true;
    } catch (_) {
      _error = errorMessage;
      notifyListeners();
      return false;
    }
  }
}
