import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../domain/models/farm_activity.dart';
import 'app_button.dart';
import 'app_text_field.dart';

/// Create-or-edit sheet for a [FarmTodoItem] (crop or livestock reminder).
///
/// Pass [initialTask] to edit an existing reminder; leave it null to create
/// a new one. When editing, [onDelete] (if provided) shows a delete action.
class TodoEditSheet extends StatefulWidget {
  const TodoEditSheet({
    super.key,
    required this.entityName,
    this.initialTask,
    this.onDelete,
  });

  final String entityName;
  final FarmTodoItem? initialTask;
  final VoidCallback? onDelete;

  @override
  State<TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends State<TodoEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late DateTime _dueDate;
  late FarmTodoPriority _priority;
  late bool _dailyReminder;
  late bool _pushEnabled;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final FarmTodoItem? task = widget.initialTask;
    _titleController = TextEditingController(
        text: task?.title ?? 'Check ${widget.entityName}');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _dueDate = task?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    _priority = task?.priority ?? FarmTodoPriority.normal;
    _dailyReminder = task?.dailyReminder ?? false;
    _pushEnabled = task?.pushNotificationEnabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _dueDate.hour, minute: _dueDate.minute),
    );
    if (time == null) return;
    setState(() {
      _dueDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      context.showSnackBar('Title is required', isError: true);
      return;
    }
    final DateTime now = DateTime.now();
    final FarmTodoItem task = widget.initialTask == null
        ? FarmTodoItem(
            id: const Uuid().v4(),
            title: title,
            notes: _notesController.text.trim(),
            dueDate: _dueDate,
            priority: _priority,
            dailyReminder: _dailyReminder,
            pushNotificationEnabled: _pushEnabled,
            createdAt: now,
            updatedAt: now,
          )
        : widget.initialTask!.copyWith(
            title: title,
            notes: _notesController.text.trim(),
            dueDate: _dueDate,
            priority: _priority,
            dailyReminder: _dailyReminder,
            pushNotificationEnabled: _pushEnabled,
            updatedAt: now,
          );
    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit reminder' : 'New reminder',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (_isEditing && widget.onDelete != null)
                      IconButton(
                        tooltip: 'Delete reminder',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onDelete!();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _titleController,
                  label: 'Title',
                  hint: 'E.g. Apply fertilizer',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _notesController,
                  label: 'Notes',
                  hint: 'Details for this reminder',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(18),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Due'),
                    child: Text(
                        '${_dueDate.day}/${_dueDate.month}/${_dueDate.year} at '
                        '${_dueDate.hour.toString().padLeft(2, '0')}:${_dueDate.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FarmTodoPriority>(
                  initialValue: _priority,
                  items: FarmTodoPriority.values
                      .map((FarmTodoPriority value) => DropdownMenuItem<
                          FarmTodoPriority>(
                          value: value, child: Text(_priorityLabel(value))))
                      .toList(),
                  onChanged: (FarmTodoPriority? value) {
                    if (value != null) setState(() => _priority = value);
                  },
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _pushEnabled,
                  onChanged: (bool? value) =>
                      setState(() => _pushEnabled = value ?? true),
                  title: const Text('Send a reminder notification'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: _dailyReminder,
                  onChanged: (bool? value) =>
                      setState(() => _dailyReminder = value ?? false),
                  title: const Text('Repeat daily until done'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton.secondary(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton.primary(
                        onPressed: _submit,
                        child: Text(_isEditing ? 'Save changes' : 'Create'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _priorityLabel(FarmTodoPriority priority) {
    switch (priority) {
      case FarmTodoPriority.low:
        return 'Low';
      case FarmTodoPriority.normal:
        return 'Normal';
      case FarmTodoPriority.high:
        return 'High';
      case FarmTodoPriority.urgent:
        return 'Urgent';
    }
  }
}
