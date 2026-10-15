import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/summary_bar.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm([Task? task]) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    if (!mounted || message == null) return;
    _showSnack(message);
  }

  Future<void> _toggle(Task task) async {
    final provider = context.read<TaskProvider>();
    final ok = await provider.toggleStatus(task);
    if (!ok && mounted) _showSnack(provider.error ?? 'Something went wrong');
  }

  Future<void> _confirmDelete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<TaskProvider>();
    final ok = await provider.deleteTask(task);
    if (!mounted) return;
    _showSnack(ok ? 'Task deleted' : provider.error ?? 'Something went wrong');
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        actions: [
          IconButton(
            tooltip: tasks.sortAscending
                ? 'Due date: earliest first'
                : 'Due date: latest first',
            icon: Icon(
              tasks.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            onPressed: tasks.toggleSortDirection,
          ),
          IconButton(
            tooltip: 'Toggle dark mode',
            icon: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: theme.toggle,
          ),
        ],
      ),
      body: Column(
        children: [
          SummaryBar(
            total: tasks.totalCount,
            pending: tasks.pendingCount,
            completed: tasks.completedCount,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchController,
              onChanged: tasks.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search by title',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          tasks.setSearchQuery('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                for (final f in TaskFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: tasks.filter == f,
                      onSelected: (_) => tasks.setFilter(f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList(tasks)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    );
  }

  Widget _buildList(TaskProvider tasks) {
    if (tasks.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = tasks.visibleTasks;
    if (items.isEmpty) {
      return tasks.hasTasks
          ? const EmptyState(
              icon: Icons.search_off,
              title: 'No matching tasks',
              message: 'Try a different search or filter.',
            )
          : const EmptyState(
              icon: Icons.task_alt,
              title: 'No tasks yet',
              message: 'Tap "Add task" to create your first task.',
            );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final task = items[i];
        return TaskCard(
          key: ValueKey(task.id),
          task: task,
          onToggle: () => _toggle(task),
          onEdit: () => _openForm(task),
          onDelete: () => _confirmDelete(task),
        );
      },
    );
  }
}
