import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    const DarwinInitializationSettings macInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );
    const InitializationSettings initSettings = InitializationSettings(
      macOS: macInitSettings,
      // Keep other platforms default; this app targets mac first
    );

    try {
      final bool? result = await _plugin.initialize(
        initSettings,
      );
      _initialized = result == true;
      developer.log('NotificationService initialized: $_initialized', name: 'NotificationService');
    } catch (e, s) {
      developer.log('Failed to initialize notifications: $e', name: 'NotificationService', error: e, stackTrace: s);
      _initialized = false;
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }

    const NotificationDetails details = NotificationDetails(
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.show(
        0,
        title,
        body,
        details,
      );
      developer.log('Notification displayed: $title - $body', name: 'NotificationService');
    } catch (e, s) {
      developer.log('Failed to show notification: $e', name: 'NotificationService', error: e, stackTrace: s);
    }
  }

  Future<void> showFinishNotification() async {
    await showInstantNotification(title: '番茄结束', body: '恭喜，你完成了一个番茄！休息一下吧');
  }
}


