import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit task' : 'Add task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: TaskValidators.description,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FormField<DateTime>(
                initialValue: _dueDate,
                validator: (v) =>
                    TaskValidators.dueDate(v, allowPast: _isEditing),
                builder: (field) => InkWell(
                  onTap: () => _pickDate(field),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Due date *',
                      border: const OutlineInputBorder(),
                      errorText: field.errorText,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(_dueDate?.displayDate ?? 'Select a date'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Priority', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TaskPriority>(
                  segments: [
                    for (final p in TaskPriority.values)
                      ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
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
