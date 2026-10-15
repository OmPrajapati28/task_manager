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
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Delete task?'),
          content: Text('"${task.title}" will be permanently deleted.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A1D24) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Text('My Tasks'),
        actions: [
          IconButton.filledTonal(
            tooltip: tasks.sortAscending
                ? 'Due date: earliest first'
                : 'Due date: latest first',
            icon: Icon(
              tasks.sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
            ),
            onPressed: tasks.toggleSortDirection,
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: 'Toggle dark mode',
            icon: Icon(
              theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            onPressed: theme.toggle,
          ),
          const SizedBox(width: 16),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: tasks.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search by title',
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    tasks.setSearchQuery('');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: scheme.primary, width: 1.6),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                for (final f in TaskFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterPill(
                      label: f.label,
                      count: switch (f) {
                        TaskFilter.all => tasks.totalCount,
                        TaskFilter.pending => tasks.pendingCount,
                        TaskFilter.completed => tasks.completedCount,
                      },
                      selected: tasks.filter == f,
                      onTap: () => tasks.setFilter(f),
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
        icon: const Icon(Icons.add_rounded),
        label: const Text('New task'),
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
        icon: Icons.search_off_rounded,
        title: 'No matching tasks',
        message: 'Try a different search or filter.',
      )
          : EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No tasks yet',
        message: 'Create your first task and stay on top of your day.',
        actionLabel: 'Add task',
        onAction: () => _openForm(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary
              : (isDark ? const Color(0xFF1A1D24) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          '$label · $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}