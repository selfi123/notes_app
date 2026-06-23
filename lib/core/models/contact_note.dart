import 'package:hive/hive.dart';

part 'contact_note.g.dart';

@HiveType(typeId: 0)
enum NoteType {
  @HiveField(0)
  text,

  @HiveField(1)
  audio,
}

@HiveType(typeId: 1)
class ContactNote extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String contactId; // Device contact identifier

  @HiveField(2)
  final String contactName;

  @HiveField(3)
  final NoteType type;

  @HiveField(4)
  final String? textContent; // For text notes

  @HiveField(5)
  final String? audioPath; // Local file path for audio notes

  @HiveField(6)
  final String? r2Key; // R2 object key for cloud-synced audio

  @HiveField(7)
  final int durationSeconds; // For audio notes

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final bool isSyncedToCloud;

  @HiveField(10)
  final DateTime? reminderAt;

  ContactNote({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.type,
    this.textContent,
    this.audioPath,
    this.r2Key,
    this.durationSeconds = 0,
    required this.createdAt,
    this.isSyncedToCloud = false,
    this.reminderAt,
  });

  ContactNote copyWith({
    String? audioPath,
    String? r2Key,
    bool? isSyncedToCloud,
    String? textContent,
    DateTime? reminderAt,
  }) {
    return ContactNote(
      id: id,
      contactId: contactId,
      contactName: contactName,
      type: type,
      textContent: textContent ?? this.textContent,
      audioPath: audioPath ?? this.audioPath,
      r2Key: r2Key ?? this.r2Key,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      isSyncedToCloud: isSyncedToCloud ?? this.isSyncedToCloud,
      reminderAt: reminderAt ?? this.reminderAt,
    );
  }
}
