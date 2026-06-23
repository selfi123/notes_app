// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_note.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContactNoteAdapter extends TypeAdapter<ContactNote> {
  @override
  final int typeId = 1;

  @override
  ContactNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContactNote(
      id: fields[0] as String,
      contactId: fields[1] as String,
      contactName: fields[2] as String,
      type: fields[3] as NoteType,
      textContent: fields[4] as String?,
      audioPath: fields[5] as String?,
      r2Key: fields[6] as String?,
      durationSeconds: fields[7] as int,
      createdAt: fields[8] as DateTime,
      isSyncedToCloud: fields[9] as bool,
      reminderAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ContactNote obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.contactId)
      ..writeByte(2)
      ..write(obj.contactName)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.textContent)
      ..writeByte(5)
      ..write(obj.audioPath)
      ..writeByte(6)
      ..write(obj.r2Key)
      ..writeByte(7)
      ..write(obj.durationSeconds)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isSyncedToCloud)
      ..writeByte(10)
      ..write(obj.reminderAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactNoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NoteTypeAdapter extends TypeAdapter<NoteType> {
  @override
  final int typeId = 0;

  @override
  NoteType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return NoteType.text;
      case 1:
        return NoteType.audio;
      default:
        return NoteType.text;
    }
  }

  @override
  void write(BinaryWriter writer, NoteType obj) {
    switch (obj) {
      case NoteType.text:
        writer.writeByte(0);
        break;
      case NoteType.audio:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
