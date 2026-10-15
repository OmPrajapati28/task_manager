/// Task model, enums and validation rules.
/// Pure Dart (no Flutter imports) so it can be unit-tested easily.

enum TaskPriority {
  low('Low'),
  medium('Medium'),
  high('High');

  const TaskPriority(this.label);
  final String label;
}

enum TaskFilter {
  all('All'),
  pending('Pending'),
  completed('Completed');

  const TaskFilter(this.label);
  final String label;
}

/// Strips the time part so dates compare by calendar day only.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

extension DateDisplay on DateTime {
  String get displayDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$day ${months[month - 1]} $year';
  }
}

class Task {
  const Task({
    this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
  });

  final int? id; // null until the row is inserted into SQLite
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isCompleted;
  final TaskPriority priority;

  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    TaskPriority? priority,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
    );
  }

  /// Object -> SQLite row.
  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'due_date': dueDate.millisecondsSinceEpoch,
        'is_completed': isCompleted ? 1 : 0,
        'priority': priority.index,
      };

  /// SQLite row -> object. Defensive about bad/missing values.
  factory Task.fromMap(Map<String, Object?> map) {
    final priorityIndex =
        (map['priority'] as int? ?? TaskPriority.medium.index)
            .clamp(0, TaskPriority.values.length - 1)
            .toInt();
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['due_date'] as int),
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      priority: TaskPriority.values[priorityIndex],
    );
  }
}

/// Validation rules shared by the form (UI) and the provider (business logic).
/// Each method returns an error message, or null when the value is valid.
class TaskValidators {
  static String? title(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Title is required';
    if (v.length < 3) return 'Title must be at least 3 characters';
    if (v.length > 100) return 'Title must be 100 characters or fewer';
    return null;
  }

  static String? description(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Description is required';
    if (v.length > 500) return 'Description must be 500 characters or fewer';
    return null;
  }

  static String? dueDate(DateTime? value, {bool allowPast = false}) {
    if (value == null) return 'Please select a due date';
    if (!allowPast && dateOnly(value).isBefore(dateOnly(DateTime.now()))) {
      return 'Due date cannot be in the past';
    }
    return null;
  }
}
