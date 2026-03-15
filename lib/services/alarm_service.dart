import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to store pending alarm payloads in SharedPreferences.
/// Format: Map<String, String> where key = alarm id, value = JSON payload
const _kAlarmPayloadsKey = 'alarm_payloads';

/// Save a medicine payload before scheduling so the background isolate can read it.
Future<void> saveAlarmPayload(int id, String payload) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kAlarmPayloadsKey) ?? '{}';
  final map = Map<String, String>.from(jsonDecode(raw) as Map);
  map[id.toString()] = payload;
  await prefs.setString(_kAlarmPayloadsKey, jsonEncode(map));
}

/// Remove a payload after the alarm fires or is cancelled.
Future<void> removeAlarmPayload(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kAlarmPayloadsKey) ?? '{}';
  final map = Map<String, String>.from(jsonDecode(raw) as Map);
  map.remove(id.toString());
  await prefs.setString(_kAlarmPayloadsKey, jsonEncode(map));
}

/// Read a previously saved payload.
Future<String?> readAlarmPayload(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kAlarmPayloadsKey) ?? '{}';
  final map = Map<String, String>.from(jsonDecode(raw) as Map);
  return map[id.toString()];
}

// ─────────────────────────────────────────────────────────────────────────────
// Background isolate callback — runs when android_alarm_manager_plus fires.
// Must be a top-level function annotated with @pragma('vm:entry-point').
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> backgroundAlarmCallback(int id) async {
  // Boot the Flutter engine in this isolate so we can use plugins.
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('[BackgroundAlarm] Fired for id=$id');

  try {
    // 1. Read medicine payload from SharedPreferences (works in background)
    final payload = await readAlarmPayload(id);
    if (payload == null) {
      debugPrint('[BackgroundAlarm] No payload for id=$id — skipping');
      return;
    }

    final map = jsonDecode(payload) as Map<String, dynamic>;
    final name    = map['name']    as String? ?? 'Medicine';
    final dosage  = map['dosage']  as String? ?? '';
    final purpose = map['purpose'] as String? ?? '';

    final title = 'Time for Medicine';
    final body  = 'Take $name${dosage.isNotEmpty ? " ($dosage)" : ""}${purpose.isNotEmpty ? " for $purpose" : ""}. Please take it now.';

    // 2. Show a fullscreen intent notification — this wakes the screen and
    //    opens the app automatically (no user tap required on most devices).
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'medicine_alarm_channel',
        'Medicine Alarms',
        channelDescription: 'Voice alarm reminders for taking medicines',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,           // ← wakes screen & opens app
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        ticker: 'Medicine Reminder',
        // Use alarm sound category so Android treats it as an alarm
        category: AndroidNotificationCategory.alarm,
      ),
    );

    await plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notifDetails,
      payload: payload,
    );

    debugPrint('[BackgroundAlarm] Fullscreen notification shown for id=$id');
  } catch (e) {
    debugPrint('[BackgroundAlarm] Error: $e');
  }
}
