import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/contact_note.dart';

class TextNoteCard extends StatelessWidget {
  final ContactNote note;
  final int index;
  final VoidCallback onDelete;
  final Future<void> Function(DateTime?) onSetReminder;

  const TextNoteCard({
    super.key,
    required this.note,
    required this.index,
    required this.onDelete,
    required this.onSetReminder,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, h:mm a').format(note.createdAt);

    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          PhosphorIcons.trash(PhosphorIconsStyle.light),
          color: AppColors.error,
          size: 20,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      PhosphorIcons.notepad(PhosphorIconsStyle.fill),
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Text Note',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(date,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: note.reminderAt ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selectedDate == null) return;

                      if (context.mounted) {
                        final selectedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                              note.reminderAt ?? DateTime.now()),
                        );
                        if (selectedTime == null) return;

                        final finalDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        onSetReminder(finalDateTime);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: note.reminderAt != null
                            ? AppColors.amber.withValues(alpha: 0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        note.reminderAt != null
                            ? PhosphorIcons.bellRinging(PhosphorIconsStyle.fill)
                            : PhosphorIcons.bell(PhosphorIconsStyle.light),
                        size: 18,
                        color: note.reminderAt != null
                            ? AppColors.amber
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Content
              Text(
                note.textContent ?? '',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      )
          .animate(delay: Duration(milliseconds: 60 * index))
          .fadeIn()
          .slideY(begin: 0.06),
    );
  }
}
