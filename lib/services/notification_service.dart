import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/notification_model.dart';
import 'alarm_service.dart';

/// Background handler — top-level, called when app is killed.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  // Nothing needed — foreground handler in main.dart handles routing.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Registered by main.dart — routes to AlarmScreen on notification tap.
  void Function(NotificationResponse)? _foregroundHandler;
  void setForegroundHandler(void Function(NotificationResponse) h) =>
      _foregroundHandler = h;

  int? _patientId;
  void setPatientId(int id) => _patientId = id;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );
  }

  void _onForegroundResponse(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped: ${response.payload}');
    _foregroundHandler?.call(response);
    // Log missed doses
    if (response.id != null && response.id! >= 10000) {
      _logMissedDose(
        title: 'Missed Dose Alert',
        body: response.payload ?? 'You missed a dose.',
      );
    }
  }

  Future<void> _logMissedDose(
      {required String title, required String body}) async {
    if (_patientId == null) return;
    try {
      await DatabaseHelper.instance.insertNotification(
        AppNotification(
          patientId: _patientId!,
          title: title,
          body: body,
          timestamp: DateTime.now().toIso8601String(),
        ).toMap(),
      );
    } catch (_) {}
  }

  // ─── Permissions ──────────────────────────────────────────────────────────

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }
  }

  // ─── Schedule ─────────────────────────────────────────────────────────────

  /// Schedule a daily notification + background alarm.
  ///
  /// [payload] JSON string: {name, dosage, purpose, id}
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    String? payload,
    Duration offset = Duration.zero,
    bool skipToday = false,
    bool isMissed = false,
  }) async {
    final now = DateTime.now();
    var scheduled =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);
    scheduled = scheduled.add(offset);
    if (skipToday) scheduled = scheduled.add(const Duration(days: 1));
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    // 1. Schedule the silent daily flutter_local_notifications reminder
    //    (shows in notification tray, tapping it also opens AlarmScreen).
    final notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        isMissed ? 'missed_dose_channel' : 'medicine_alarm_channel',
        isMissed ? 'Missed Dose Alerts' : 'Medicine Alarms',
        channelDescription: isMissed
            ? 'Alerts for missed medication doses'
            : 'Voice alarm reminders',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: !isMissed,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        ticker: 'Medicine Reminder',
        category: isMissed
            ? AndroidNotificationCategory.reminder
            : AndroidNotificationCategory.alarm,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      payload: payload,
    );

    // 2. For primary alarms (not missed-dose): also schedule the
    //    android_alarm_manager_plus one-shot that wakes the device and fires
    //    a fullscreen notification + opens the app automatically.
    if (!isMissed && payload != null) {
      // Save payload so background isolate can read it
      await saveAlarmPayload(id, payload);

      await AndroidAlarmManager.oneShotAt(
        scheduled,
        id,
        backgroundAlarmCallback,
        exact: true,
        wakeup: true,          // wakes sleeping device
        rescheduleOnReboot: true,
        allowWhileIdle: true,
      );
      debugPrint(
          '[NotificationService] Alarm scheduled for id=$id at $scheduled');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
    await AndroidAlarmManager.cancel(id);
    await removeAlarmPayload(id);
    debugPrint('[NotificationService] Cancelled id=$id');
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
