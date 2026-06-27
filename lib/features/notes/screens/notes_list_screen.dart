import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../core/models/contact_note.dart';
import '../widgets/text_note_card.dart';
import '../widgets/audio_note_card.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: notes.isEmpty
                  ? _buildEmptyState(context)
                  : settings.useFolderLayout
                  ? _buildFolderList(context, notes)
                  : _buildNotesList(context, ref, notes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Notes',
            style: Theme.of(context).textTheme.displayLarge,
          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
          const SizedBox(height: 4),
          Text(
            'All saved notes across your contacts',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ).animate().fadeIn(delay: 150.ms),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsThin.notebook,
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
            'Saved notes will appear here',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
    );
  }

  Widget _buildNotesList(
    BuildContext context,
    WidgetRef ref,
    List<ContactNote> notes,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final child = note.type == NoteType.text
            ? TextNoteCard(
                note: note,
                index: index,
                onDelete: () =>
                    ref.read(notesProvider.notifier).deleteNote(note.id),
                onSetReminder: (dt) =>
                    ref.read(notesProvider.notifier).setReminder(note.id, dt),
              )
            : AudioNoteCard(
                note: note,
                index: index,
                onDelete: () =>
                    ref.read(notesProvider.notifier).deleteNote(note.id),
                onSetReminder: (dt) =>
                    ref.read(notesProvider.notifier).setReminder(note.id, dt),
              );

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show the contact name above the note card in the global feed
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsLight.user,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      note.contactName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              child,
            ],
          ),
        );
      },
    );
  }

  Widget _buildFolderList(BuildContext context, List<ContactNote> notes) {
    // Group notes by contactId
    final Map<String, List<ContactNote>> grouped = {};
    for (final n in notes) {
      if (!grouped.containsKey(n.contactId)) {
        grouped[n.contactId] = [];
      }
      grouped[n.contactId]!.add(n);
    }

    final contacts = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contactId = contacts[index];
        final contactNotes = grouped[contactId]!;
        final contactName = contactNotes.first.contactName;
        final count = contactNotes.length;

        final initials = contactName
            .split(' ')
            .take(2)
            .map((s) => s.isNotEmpty ? s[0] : '')
            .join()
            .toUpperCase();

        return GestureDetector(
          onTap: () => context.pushNamed(
            'contact-detail',
            pathParameters: {'id': contactId},
            queryParameters: {'name': contactName},
          ),
          child:
              Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: AppColors.amber,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contactName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '$count ${count == 1 ? 'note' : 'notes'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          PhosphorIconsLight.caretRight,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 50 * index))
                  .slideX(begin: 0.05),
        );
      },
    );
  }
}
