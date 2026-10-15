import 'package:flutter/material.dart';

import '../models/task.dart';

/// One row in the task list. Completed tasks are struck through, greyed out
/// and shown on a muted card; overdue pending tasks get a red due date.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.isCompleted;
    final overdue =
        !done && dateOnly(task.dueDate).isBefore(dateOnly(DateTime.now()));

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      decoration: done ? TextDecoration.lineThrough : null,
      color: done ? theme.colorScheme.outline : null,
    );
    final dateColor = overdue ? theme.colorScheme.error : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: done ? theme.colorScheme.surfaceContainerHighest : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: done, onChanged: (_) => onToggle()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(task.title, style: titleStyle),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: done ? theme.colorScheme.outline : null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event, size: 16, color: dateColor),
                            const SizedBox(width: 4),
                            Text(
                              task.dueDate.displayDate,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: dateColor),
                            ),
                          ],
                        ),
                        _PriorityBadge(priority: task.priority),
                        Text(
                          done
                              ? 'Completed'
                              : overdue
                                  ? 'Overdue'
                                  : 'Pending',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: done
                                ? Colors.green
                                : overdue
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete task',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final TaskPriority priority;

  Color get _color => switch (priority) {
        TaskPriority.low => Colors.green,
        TaskPriority.medium => Colors.orange,
        TaskPriority.high => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: _color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _color,
        ),
      ),
    );
  }
}
