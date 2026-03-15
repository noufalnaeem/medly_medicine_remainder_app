import 'dart:convert';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'views/splash_screen.dart';
import 'views/alarm_screen.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService().init();
  await AndroidAlarmManager.initialize();
  NotificationService().setForegroundHandler(_handleNotificationResponse);
  await _checkInitialNotification();

  runApp(const MedicineReminderApp());
}

void _handleNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  final id = response.id ?? 0;
  if (id >= 10000) return;
  _navigateToAlarm(payload);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _navigateToAlarm(String payload) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => AlarmScreen.fromPayload(payload),
      fullscreenDialog: true,
    ),
  );
}

Future<void> _checkInitialNotification() async {
  final plugin = FlutterLocalNotificationsPlugin();
  final details = await plugin.getNotificationAppLaunchDetails();
  if (details?.didNotificationLaunchApp == true) {
    final response = details!.notificationResponse;
    if (response?.payload != null) {
      final id = response!.id ?? 0;
      if (id < 10000) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToAlarm(response.payload!);
        });
      }
    }
  }
}

class MedicineReminderApp extends StatelessWidget {
  const MedicineReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Medly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      home: SplashScreen(),
    );
  }
}
