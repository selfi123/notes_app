import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/contact_note.dart';
import '../../notes/widgets/audio_note_card.dart';
import '../../notes/widgets/text_note_card.dart';

class ContactDetailScreen extends ConsumerWidget {
  final String contactId;
  final String contactName;

  const ContactDetailScreen({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  String _initials(String name) {
    return name
        .split(' ')
        .take(2)
        .map((s) => s.isNotEmpty ? s[0] : '')
        .join()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesForContactProvider(contactId));
    final canAdd = ref.watch(notesProvider.notifier).canAddNote;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, notes.length),
            Expanded(
              child: notes.isEmpty
                  ? _buildEmptyNotes(context)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: note.type == NoteType.audio
                              ? AudioNoteCard(
                                  note: note,
                                  index: index,
                                  onDelete: () => ref
                                      .read(notesProvider.notifier)
                                      .deleteNote(note.id),
                                  onSetReminder: (dt) => ref
                                      .read(notesProvider.notifier)
                                      .setReminder(note.id, dt),
                                )
                              : TextNoteCard(
                                  note: note,
                                  index: index,
                                  onDelete: () => ref
                                      .read(notesProvider.notifier)
                                      .deleteNote(note.id),
                                  onSetReminder: (dt) => ref
                                      .read(notesProvider.notifier)
                                      .setReminder(note.id, dt),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: () => context.pushNamed(
                'add-note',
                pathParameters: {'id': contactId},
                queryParameters: {'name': contactName},
              ),
              backgroundColor: AppColors.amber,
              elevation: 0,
              child: Icon(
                PhosphorIconsBold.plus,
                color: Colors.white,
              ),
            ).animate().scale(delay: 300.ms)
          : _buildUpgradeFab(context),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, int noteCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    PhosphorIconsLight.caretLeft,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.amber.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                _initials(contactName),
                style: const TextStyle(
                  color: AppColors.amber,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ).animate().scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: 12),
          Text(
            contactName,
            style: Theme.of(context).textTheme.headlineLarge,
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 4),
          Text(
            '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ).animate().fadeIn(delay: 150.ms),
        ],
      ),
    );
  }

  Widget _buildEmptyNotes(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsThin.notepad,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No notes yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first audio or text note',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildUpgradeFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => context.pushNamed('premium'),
      backgroundColor: AppColors.amberDim,
      elevation: 0,
      icon: Icon(
        PhosphorIconsFill.crown,
        color: AppColors.amber,
        size: 18,
      ),
      label: Text(
        'Upgrade',
        style: TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600),
      ),
    ).animate().scale(delay: 300.ms);
  }
}
