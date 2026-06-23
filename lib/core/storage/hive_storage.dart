import 'package:hive_flutter/hive_flutter.dart';

import '../models/contact_note.dart';
import '../models/app_settings.dart';

class HiveStorage {
  static const String notesBox = 'notes';
  static const String settingsBox = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(ContactNoteAdapter());
    Hive.registerAdapter(NoteTypeAdapter());
    Hive.registerAdapter(AppSettingsAdapter());

    // Open boxes
    await Hive.openBox<ContactNote>(notesBox);
    await Hive.openBox<AppSettings>(settingsBox);
  }

  static Box<ContactNote> get notesBoxInstance =>
      Hive.box<ContactNote>(notesBox);

  static Box<AppSettings> get settingsBoxInstance =>
      Hive.box<AppSettings>(settingsBox);
}
