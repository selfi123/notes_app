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
import 'dart:io';

const _uuid = Uuid();

Map<String, dynamic> _noteToMap(ContactNote note) {
  return {
    'id': note.id,
    'contactId': note.contactId,
    'contactName': note.contactName,
    'type': note.type.name,
    'textContent': note.textContent,
    'audioPath': note.audioPath,
    'r2Key': note.r2Key,
    'durationSeconds': note.durationSeconds,
    'createdAt': note.createdAt.toIso8601String(),
    'isSyncedToCloud': note.isSyncedToCloud,
    'reminderAt': note.reminderAt?.toIso8601String(),
  };
}

ContactNote _noteFromMap(Map<String, dynamic> map) {
  return ContactNote(
    id: map['id'] as String,
    contactId: map['contactId'] as String,
    contactName: map['contactName'] as String,
    type: map['type'] == 'audio' ? NoteType.audio : NoteType.text,
    textContent: map['textContent'] as String?,
    audioPath: map['audioPath'] as String?,
    r2Key: map['r2Key'] as String?,
    durationSeconds: map['durationSeconds'] as int? ?? 0,
    createdAt: map['createdAt'] != null
        ? DateTime.parse(map['createdAt'] as String)
        : DateTime.now(),
    isSyncedToCloud: map['isSyncedToCloud'] as bool? ?? false,
    reminderAt: map['reminderAt'] != null
        ? DateTime.parse(map['reminderAt'] as String)
        : null,
  );
}

// ─── Auth & IAP Providers ─────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges;
});

final userDocProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
    },
    error: (_, __) => const Stream.empty(),
    loading: () => const Stream.empty(),
  );
});

final iapProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  return await IapService.fetchProducts();
});

// ─── Settings Provider ────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(AppSettings()) {
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
    final wasPremium = state.isActivePremium;
    state = AppSettings(
      isPremium: isPremium,
      premiumExpiresAt: expiresAt,
      razorpaySubscriptionId: subscriptionId ?? state.razorpaySubscriptionId,
      cloudSyncEnabled: isPremium,
      lastSyncAt: state.lastSyncAt,
      useFolderLayout: state.useFolderLayout,
    );
    _save();

    // If newly upgraded to premium, trigger sync of unsynced notes!
    if (isPremium && !wasPremium) {
      _ref.read(notesProvider.notifier).syncUnsyncedNotes();
    }
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

  AppSettings get settings => state;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) {
    final notifier = SettingsNotifier(ref);

    // Reactively listen to auth state changes to clear premium status when logged out
    ref.listen<AsyncValue<User?>>(
      authStateProvider,
      (previous, next) {
        final user = next.value;
        if (user == null) {
          if (notifier.settings.isPremium) {
            notifier.setPremium(
              isPremium: false,
              expiresAt: null,
            );
          }
        } else {
          if (previous?.value == null) {
            IapService.restorePurchases();
          }
        }
      },
      fireImmediately: true,
    );

    // Reactively listen to user doc for premium updates
    ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
      userDocProvider,
      (previous, next) {
        final userDoc = next.value;
        if (userDoc != null && userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            final isPremium = data['isPremium'] == true;
            final expires = data['premiumExpiresAt'] as Timestamp?;
            final expiresAt = expires?.toDate();

            final currentSettings = notifier.settings;

            if (currentSettings.isPremium != isPremium ||
                currentSettings.premiumExpiresAt != expiresAt) {
              notifier.setPremium(
                isPremium: isPremium,
                expiresAt: expiresAt,
              );
            }

            if (isPremium && (expiresAt == null || expiresAt.isAfter(DateTime.now()))) {
              ref.read(notesProvider.notifier).fetchAndMergeNotesFromCloud();
            }
          }
        } else {
          // If no user document is found (e.g. document deleted),
          // set premium to false if currently marked premium.
          if (notifier.settings.isPremium) {
            notifier.setPremium(
              isPremium: false,
              expiresAt: null,
            );
          }
        }
      },
      fireImmediately: true,
    );

    return notifier;
  },
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
    ContactNote note = ContactNote(
      id: _uuid.v4(),
      contactId: contactId,
      contactName: contactName,
      type: NoteType.text,
      textContent: text,
      createdAt: DateTime.now(),
      isSyncedToCloud: false,
    );

    await HiveStorage.notesBoxInstance.put(note.id, note);

    final isPremium = _ref.read(settingsProvider).isActivePremium;
    if (isPremium) {
      try {
        final user = AuthService.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notes')
              .doc(note.id)
              .set(_noteToMap(note.copyWith(isSyncedToCloud: true)));

          note = note.copyWith(isSyncedToCloud: true);
          await HiveStorage.notesBoxInstance.put(note.id, note);
        }
      } catch (_) {}
    }

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

        // Upload metadata to Firestore!
        final user = AuthService.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notes')
              .doc(note.id)
              .set(_noteToMap(note));
        }

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
    if (note != null) {
      if (note.r2Key != null) {
        try {
          await R2Service.deleteAudio(note.r2Key!);
        } catch (_) {}
      }

      final user = AuthService.currentUser;
      final isPremium = _ref.read(settingsProvider).isActivePremium;
      if (isPremium && user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notes')
              .doc(noteId)
              .delete();
        } catch (_) {}
      }
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

  Future<void> fetchAndMergeNotesFromCloud() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final isPremium = _ref.read(settingsProvider).isActivePremium;
    if (!isPremium) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notes')
          .get();

      final box = HiveStorage.notesBoxInstance;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final note = _noteFromMap(data);

        // If it is an audio note, and we don't have it locally in our cache,
        // we can download it from R2!
        String? localPath = note.audioPath;
        if (note.type == NoteType.audio && note.r2Key != null) {
          final fileExists = localPath != null && localPath.isNotEmpty && await File(localPath).exists();
          if (!fileExists) {
            try {
              localPath = await R2Service.downloadAudio(objectKey: note.r2Key!);
            } catch (e) {
              print("Failed to download audio for note ${note.id}: $e");
            }
          }
        }

        final updatedNote = note.copyWith(audioPath: localPath, isSyncedToCloud: true);
        await box.put(note.id, updatedNote);
      }
      _load();
    } catch (e) {
      print("Failed to fetch notes from cloud: $e");
    }
  }

  Future<void> syncUnsyncedNotes() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    // Check if user is premium
    final isPremium = _ref.read(settingsProvider).isActivePremium;
    if (!isPremium) return;

    // Filter notes that are not synced to the cloud
    final unsynced = state.where((note) => !note.isSyncedToCloud).toList();
    if (unsynced.isEmpty) return;

    for (final note in unsynced) {
      try {
        ContactNote updated = note;
        if (note.type == NoteType.audio && note.audioPath != null && note.audioPath!.isNotEmpty) {
          final key = R2Service.buildKey(contactId: note.contactId, noteId: note.id);
          await R2Service.uploadAudio(localPath: note.audioPath!, objectKey: key);
          updated = note.copyWith(r2Key: key, isSyncedToCloud: true);
        } else {
          updated = note.copyWith(isSyncedToCloud: true);
        }

        // Upload to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notes')
            .doc(note.id)
            .set(_noteToMap(updated));

        await HiveStorage.notesBoxInstance.put(note.id, updated);
      } catch (e) {
        print("Failed to sync note ${note.id}: $e");
      }
    }

    _load();
    _ref.read(settingsProvider.notifier).updateLastSync();
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
