import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../models/contact_note.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked: ${details.payload}');
        // You can handle routing here based on payload if needed
      },
    );
  }

  static Future<bool> requestPermissions() async {
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      final exactAlarm = await androidImplementation.requestExactAlarmsPermission();
      return (granted ?? false) && (exactAlarm ?? false);
    }
    return true;
  }

  static Future<void> scheduleReminder({required ContactNote note}) async {
    if (note.reminderAt == null) return;

    // Ensure permissions are granted before scheduling
    await requestPermissions();

    // Use note.id.hashCode as the notification ID
    final id = note.id.hashCode;

    // Don't schedule in the past
    if (note.reminderAt!.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(note.reminderAt!, tz.local);

    final Int32List insistentFlag = Int32List.fromList(<int>[4]); // FLAG_INSISTENT

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'notes_alarms_channel_2',
      'Note Alarms',
      channelDescription: 'Continuous alarms for your saved notes',
      importance: Importance.max,
      priority: Priority.high,
      additionalFlags: insistentFlag,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final String body = note.type == NoteType.text
        ? (note.textContent ?? 'You have a saved text note.')
        : 'You have a saved audio note.';

    await _notificationsPlugin.zonedSchedule(
      id,
      'Reminder: ${note.contactName}',
      body,
      scheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: note.id,
    );
  }

  static Future<void> cancelReminder(String noteId) async {
    await _notificationsPlugin.cancel(noteId.hashCode);
  }
}
