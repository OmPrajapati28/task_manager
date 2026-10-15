import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';

/// Used for both adding (task == null) and editing (task != null).
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.task});

  final Task? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  DateTime? _dueDate;
  late TaskPriority _priority;
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _dueDate = t?.dueDate;
    _priority = t?.priority ?? TaskPriority.medium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(
      String label, {
        String? hint,
        IconData? icon,
        String? errorText,
        bool alignLabelWithHint = false,
      }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
      border: border(scheme.outlineVariant),
      enabledBorder: border(scheme.outlineVariant),
      focusedBorder: border(scheme.primary, 1.6),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, 1.6),
    );
  }

  Future<void> _pickDate(FormFieldState<DateTime> field) async {
    final today = dateOnly(DateTime.now());
    final initial = _dueDate ?? today;
    // Editing an overdue task must still be able to show its current date.
    final firstDate = initial.isBefore(today) ? initial : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(today.year + 10),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
    field.didChange(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final provider = context.read<TaskProvider>();
    final task = Task(
      id: widget.task?.id,
      title: _titleController.text,
      description: _descriptionController.text,
      dueDate: _dueDate!,
      isCompleted: widget.task?.isCompleted ?? false,
      priority: _priority,
    );

    final ok = await provider.saveTask(task);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(_isEditing ? 'Task updated' : 'Task added');
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Something went wrong')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text(_isEditing ? 'Edit task' : 'New task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: TaskValidators.title,
                decoration: _decoration(
                  'Title *',
                  hint: 'What needs to be done?',
                  icon: Icons.title_rounded,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: TaskValidators.description,
                decoration: _decoration(
                  'Description *',
                  hint: 'Add some details',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              FormField<DateTime>(
                initialValue: _dueDate,
                validator: (v) =>
                    TaskValidators.dueDate(v, allowPast: _isEditing),
                builder: (field) => InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _pickDate(field),
                  child: InputDecorator(
                    decoration: _decoration(
                      'Due date *',
                      icon: Icons.event_rounded,
                      errorText: field.errorText,
                    ),
                    child: Text(
                      _dueDate?.displayDate ?? 'Select a date',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _dueDate == null
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Priority',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final p in TaskPriority.values)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: p == TaskPriority.high ? 0 : 10,
                        ),
                        child: _PriorityChoice(
                          priority: p,
                          selected: _priority == p,
                          onTap: () => setState(() => _priority = p),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.check_rounded),
                  label: Text(_isEditing ? 'Save changes' : 'Add task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChoice extends StatelessWidget {
  const _PriorityChoice({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TaskPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = TaskCard.priorityColor(priority);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : (isDark ? const Color(0xFF1A1D24) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.flag_rounded,
              size: 20,
              color: selected ? color : theme.colorScheme.outline,
            ),
            const SizedBox(height: 4),
            Text(
              priority.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? color : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}