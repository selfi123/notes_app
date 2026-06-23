import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/contact_note.dart';
import '../models/app_settings.dart';
import '../storage/hive_storage.dart';
import '../services/r2_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/iap_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const _uuid = Uuid();

// ─── Auth & IAP Providers ─────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges;
});

final userDocProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((ref) {
  return AuthService.userDocStream;
});

final iapProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  return await IapService.fetchProducts();
});

// ─── Settings Provider ────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _load();
  }

  void _load() {
    final stored = HiveStorage.settingsBoxInstance.get('settings');
    if (stored != null) state = stored;
  }

  Future<void> _save() async {
    await HiveStorage.settingsBoxInstance.put('settings', state);
  }

  void setPremium({
    required bool isPremium,
    required DateTime? expiresAt,
    String? subscriptionId,
  }) {
    state = AppSettings(
      isPremium: isPremium,
      premiumExpiresAt: expiresAt,
      razorpaySubscriptionId: subscriptionId ?? state.razorpaySubscriptionId,
      cloudSyncEnabled: isPremium,
      lastSyncAt: state.lastSyncAt,
      useFolderLayout: state.useFolderLayout,
    );
    _save();
  }

  void updateLastSync() {
    state = AppSettings(
      isPremium: state.isPremium,
      premiumExpiresAt: state.premiumExpiresAt,
      razorpaySubscriptionId: state.razorpaySubscriptionId,
      cloudSyncEnabled: state.cloudSyncEnabled,
      lastSyncAt: DateTime.now(),
      useFolderLayout: state.useFolderLayout,
    );
    _save();
  }

  void toggleFolderLayout(bool useFolder) {
    state = AppSettings(
      isPremium: state.isPremium,
      premiumExpiresAt: state.premiumExpiresAt,
      razorpaySubscriptionId: state.razorpaySubscriptionId,
      cloudSyncEnabled: state.cloudSyncEnabled,
      lastSyncAt: state.lastSyncAt,
      useFolderLayout: useFolder,
    );
    _save();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

// ─── Notes Provider ────────────────────────────────────────────

class NotesNotifier extends StateNotifier<List<ContactNote>> {
  final Ref _ref;

  NotesNotifier(this._ref) : super([]) {
    _load();
  }

  void _load() {
    final box = HiveStorage.notesBoxInstance;
    state = box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ContactNote> notesForContact(String contactId) {
    return state
        .where((n) => n.contactId == contactId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get totalNoteCount => state.length;

  bool get canAddNote {
    // If we have a user doc and they are premium
    final userDoc = _ref.read(userDocProvider).value;
    if (userDoc != null && userDoc.exists) {
      final data = userDoc.data();
      if (data != null && data['isPremium'] == true) {
        final expires = data['premiumExpiresAt'] as Timestamp?;
        if (expires != null && expires.toDate().isAfter(DateTime.now())) {
          return true; // Active premium
        }
      }
    }
    
    // Fallback to local settings (useful if offline and previously cached)
    final settings = _ref.read(settingsProvider);
    if (settings.isActivePremium) return true;
    
    return totalNoteCount < 50; // Free tier limit
  }

  Future<ContactNote> addTextNote({
    required String contactId,
    required String contactName,
    required String text,
  }) async {
    final note = ContactNote(
      id: _uuid.v4(),
      contactId: contactId,
      contactName: contactName,
      type: NoteType.text,
      textContent: text,
      createdAt: DateTime.now(),
    );

    await HiveStorage.notesBoxInstance.put(note.id, note);
    _load();
    return note;
  }

  Future<ContactNote> addAudioNote({
    required String contactId,
    required String contactName,
    required String audioPath,
    required int durationSeconds,
  }) async {
    final id = _uuid.v4();
    ContactNote note = ContactNote(
      id: id,
      contactId: contactId,
      contactName: contactName,
      type: NoteType.audio,
      audioPath: audioPath,
      durationSeconds: durationSeconds,
      createdAt: DateTime.now(),
    );

    await HiveStorage.notesBoxInstance.put(note.id, note);

    // Upload to R2 if premium
    bool isPremium = false;
    final userDoc = _ref.read(userDocProvider).value;
    if (userDoc != null && userDoc.exists && userDoc.data()?['isPremium'] == true) {
      final expires = userDoc.data()?['premiumExpiresAt'] as Timestamp?;
      if (expires != null && expires.toDate().isAfter(DateTime.now())) {
        isPremium = true;
      }
    }

    if (isPremium || _ref.read(settingsProvider).isActivePremium) {
      try {
        final key = R2Service.buildKey(contactId: contactId, noteId: id);
        await R2Service.uploadAudio(localPath: audioPath, objectKey: key);

        note = note.copyWith(r2Key: key, isSyncedToCloud: true);
        await HiveStorage.notesBoxInstance.put(note.id, note);
        _ref.read(settingsProvider.notifier).updateLastSync();
      } catch (_) {
        // Cloud sync failed silently — local note is still saved
      }
    }

    _load();
    return note;
  }

  Future<void> deleteNote(String noteId) async {
    final note = HiveStorage.notesBoxInstance.get(noteId);
    if (note != null && note.r2Key != null) {
      try {
        await R2Service.deleteAudio(note.r2Key!);
      } catch (_) {}
    }
    await HiveStorage.notesBoxInstance.delete(noteId);
    await NotificationService.cancelReminder(noteId);
    _load();
  }

  Future<void> setReminder(String noteId, DateTime? reminderAt) async {
    final note = HiveStorage.notesBoxInstance.get(noteId);
    if (note == null) return;

    final updated = note.copyWith(reminderAt: reminderAt);
    await HiveStorage.notesBoxInstance.put(noteId, updated);

    if (reminderAt != null) {
      await NotificationService.scheduleReminder(note: updated);
    } else {
      await NotificationService.cancelReminder(noteId);
    }
    
    _load();
  }
}

final notesProvider = StateNotifierProvider<NotesNotifier, List<ContactNote>>(
  (ref) => NotesNotifier(ref),
);

final notesForContactProvider =
    Provider.family<List<ContactNote>, String>((ref, contactId) {
  final notes = ref.watch(notesProvider);
  return notes
      .where((n) => n.contactId == contactId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});
