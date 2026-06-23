import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/audio_service.dart';

enum _NoteMode { text, audio }

class AddNoteScreen extends ConsumerStatefulWidget {
  final String contactId;
  final String contactName;

  const AddNoteScreen({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  @override
  ConsumerState<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends ConsumerState<AddNoteScreen> {
  _NoteMode _mode = _NoteMode.audio;
  final _textController = TextEditingController();
  bool _saving = false;

  // Audio recording state
  bool _isRecording = false;
  bool _hasRecording = false;
  String? _recordedPath;
  int _recordingSeconds = 0;
  Timer? _timer;
  List<double> _amplitudeHistory = List.filled(30, 0.0);
  StreamSubscription<double>? _ampSub;
  int _recordedDurationSec = 0;

  @override
  void dispose() {
    _textController.dispose();
    _timer?.cancel();
    _ampSub?.cancel();
    AudioService.stop();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await AudioService.hasPermission();
    if (!hasPermission) {
      _showSnack('Microphone permission required');
      return;
    }

    final noteId = DateTime.now().millisecondsSinceEpoch.toString();
    _recordedPath = await AudioService.startRecording(noteId: noteId);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordingSeconds++);
    });

    _ampSub = AudioService.amplitudeStream().listen((amp) {
      setState(() {
        _amplitudeHistory = [..._amplitudeHistory.skip(1), amp];
      });
    });

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _amplitudeHistory = List.filled(30, 0.0);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    _ampSub?.cancel();
    await AudioService.stop();

    await AudioService.stopRecording(_recordedPath!);
    _recordedDurationSec = _recordingSeconds;

    setState(() {
      _isRecording = false;
      _hasRecording = true;
    });
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);

    try {
      if (_mode == _NoteMode.text) {
        final text = _textController.text.trim();
        if (text.isEmpty) {
          _showSnack('Please write something first');
          return;
        }
        await ref.read(notesProvider.notifier).addTextNote(
              contactId: widget.contactId,
              contactName: widget.contactName,
              text: text,
            );
      } else {
        if (_recordedPath == null || !_hasRecording) {
          _showSnack('Please record something first');
          return;
        }
        await ref.read(notesProvider.notifier).addAudioNote(
              contactId: widget.contactId,
              contactName: widget.contactName,
              audioPath: _recordedPath!,
              durationSeconds: _recordedDurationSec,
            );
      }

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildContactChip(),
            _buildModeToggle(),
            Expanded(
              child: _mode == _NoteMode.text
                  ? _buildTextMode()
                  : _buildAudioMode(),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
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
                PhosphorIcons.x(PhosphorIconsStyle.light),
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'New Note',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildContactChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.amberDim.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.user(PhosphorIconsStyle.fill),
                  size: 13, color: AppColors.amber),
              const SizedBox(width: 6),
              Text(
                widget.contactName,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.amberLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _ModeTab(
              icon: PhosphorIcons.microphone(
                _mode == _NoteMode.audio
                    ? PhosphorIconsStyle.fill
                    : PhosphorIconsStyle.light,
              ),
              label: 'Voice',
              selected: _mode == _NoteMode.audio,
              onTap: () => setState(() => _mode = _NoteMode.audio),
            ),
            _ModeTab(
              icon: PhosphorIcons.textT(
                _mode == _NoteMode.text
                    ? PhosphorIconsStyle.fill
                    : PhosphorIconsStyle.light,
              ),
              label: 'Text',
              selected: _mode == _NoteMode.text,
              onTap: () => setState(() => _mode = _NoteMode.text),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMode() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Waveform visualization
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(30, (i) {
                final height = (_amplitudeHistory[i] * 60).clamp(4.0, 60.0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 3,
                  height: height,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? AppColors.amber.withValues(alpha: 0.6 + _amplitudeHistory[i] * 0.4)
                        : AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 32),

          // Timer
          Text(
            _formatTime(_recordingSeconds),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: _isRecording ? AppColors.amber : AppColors.textSecondary,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording
                ? 'Recording...'
                : _hasRecording
                    ? 'Recording saved — tap Save to confirm'
                    : 'Tap to start recording',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),

          // Record button
          GestureDetector(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.amber.withValues(alpha: 0.15),
                border: Border.all(
                  color: _isRecording ? AppColors.error : AppColors.amber,
                  width: 2,
                ),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 28 : 48,
                  height: _isRecording ? 28 : 48,
                  decoration: BoxDecoration(
                    shape:
                        _isRecording ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius:
                        _isRecording ? BorderRadius.circular(6) : null,
                    color: _isRecording ? AppColors.error : AppColors.amber,
                  ),
                ),
              ),
            ),
          )
              .animate(
                onPlay: _isRecording ? (c) => c.repeat(reverse: true) : null,
              )
              .scale(
                begin: const Offset(1.0, 1.0),
                end: _isRecording ? const Offset(1.06, 1.06) : const Offset(1.0, 1.0),
                duration: 600.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }

  Widget _buildTextMode() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: _textController,
          maxLines: null,
          expands: true,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'What did they say...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(20),
          ),
          autofocus: true,
          textAlignVertical: TextAlignVertical.top,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _saving ? null : _saveNote,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.amberDim,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Save Note',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.white),
                ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.amber.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? AppColors.amber : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color:
                          selected ? AppColors.amber : AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
