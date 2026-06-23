import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/contact_note.dart';
import '../../../core/services/audio_service.dart';

class AudioNoteCard extends StatefulWidget {
  final ContactNote note;
  final int index;
  final VoidCallback onDelete;
  final Future<void> Function(DateTime?) onSetReminder;

  const AudioNoteCard({
    super.key,
    required this.note,
    required this.index,
    required this.onDelete,
    required this.onSetReminder,
  });

  @override
  State<AudioNoteCard> createState() => _AudioNoteCardState();
}

class _AudioNoteCardState extends State<AudioNoteCard> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await AudioService.pause();
      if (!mounted) return;
      setState(() => _isPlaying = false);
      return;
    }

    final path = widget.note.audioPath;
    if (path == null) return;

    _posSub?.cancel();
    _stateSub?.cancel();

    final duration = await AudioService.play(path);
    if (!mounted) return;
    setState(() {
      _isPlaying = true;
      _total = duration ?? Duration.zero;
    });

    _posSub = AudioService.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _stateSub = AudioService.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      }
    });
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress {
    if (_total.inMilliseconds == 0) return 0.0;
    return (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, h:mm a').format(widget.note.createdAt);
    final duration = widget.note.durationSeconds;

    return Dismissible(
      key: Key(widget.note.id),
      direction: DismissDirection.endToStart,
      background: _buildSwipeBackground(),
      onDismissed: (_) => widget.onDelete(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      PhosphorIcons.waveform(PhosphorIconsStyle.fill),
                      size: 16,
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Voice Note',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(date,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (widget.note.isSyncedToCloud) ...[
                    Icon(PhosphorIcons.cloudCheck(PhosphorIconsStyle.fill),
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: widget.note.reminderAt ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selectedDate == null) return;

                      if (context.mounted) {
                        final selectedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                              widget.note.reminderAt ?? DateTime.now()),
                        );
                        if (selectedTime == null) return;

                        final finalDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        widget.onSetReminder(finalDateTime);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.note.reminderAt != null
                            ? AppColors.amber.withValues(alpha: 0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.note.reminderAt != null
                            ? PhosphorIcons.bellRinging(PhosphorIconsStyle.fill)
                            : PhosphorIcons.bell(PhosphorIconsStyle.light),
                        size: 18,
                        color: widget.note.reminderAt != null
                            ? AppColors.amber
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Mini waveform bars (static decorative)
              SizedBox(
                height: 28,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(40, (i) {
                    final heights = [
                      0.3, 0.5, 0.8, 0.4, 0.9, 0.6, 0.3, 0.7, 0.5, 0.9,
                      0.4, 0.6, 0.8, 0.3, 0.5, 0.7, 0.9, 0.4, 0.6, 0.8,
                      0.5, 0.3, 0.7, 0.9, 0.4, 0.6, 0.8, 0.5, 0.3, 0.7,
                      0.9, 0.4, 0.6, 0.3, 0.8, 0.5, 0.7, 0.4, 0.9, 0.6,
                    ];
                    final h = heights[i % heights.length];
                    final filled = i < (_progress * 40).round();
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 2.5,
                      height: (h * 24).clamp(3.0, 24.0),
                      decoration: BoxDecoration(
                        color: filled
                            ? AppColors.amber
                            : AppColors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),

              // Controls row
              Row(
                children: [
                  GestureDetector(
                    onTap: _togglePlay,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isPlaying
                            ? AppColors.amber
                            : AppColors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying
                            ? PhosphorIcons.pause(PhosphorIconsStyle.fill)
                            : PhosphorIcons.play(PhosphorIconsStyle.fill),
                        size: 16,
                        color: _isPlaying
                            ? Colors.white
                            : AppColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isPlaying
                        ? '${_format(_position)} / ${_format(_total)}'
                        : '${duration}s',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      )
          .animate(delay: Duration(milliseconds: 60 * widget.index))
          .fadeIn()
          .slideY(begin: 0.06),
    );
  }

  Widget _buildSwipeBackground() {
    return Container(
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
    );
  }
}
