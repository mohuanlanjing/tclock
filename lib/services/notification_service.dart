import 'dart:developer' as developer;
import 'dart:io' show Platform, Process;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const String _macSystemSoundPath = '/System/Library/Sounds/Glass.aiff';

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
        sound: 'Glass.aiff',
        interruptionLevel: InterruptionLevel.timeSensitive,
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
    if (!_initialized) {
      await init();
    }

    // macOS: 只发一次通知，禁用通知自带短音；改为外部播放约3秒系统音
    // 其他平台：保留通知自带提示音
    final bool isMac = Platform.isMacOS;
    final NotificationDetails details = NotificationDetails(
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: !isMac,
        // 如需自定义音频，可将文件打包到应用并在此指定名称
        sound: isMac ? null : 'Glass.aiff',
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    try {
      await _plugin.show(
        0,
        '番茄结束',
        '恭喜，你完成了一个番茄！休息一下吧',
        details,
      );
      developer.log('Finish notification displayed', name: 'NotificationService');
    } catch (e, s) {
      developer.log('Failed to show finish notification: $e', name: 'NotificationService', error: e, stackTrace: s);
    }

    if (isMac) {
      await _playMacSystemSoundMulti(times: 3, singleDuration: const Duration(seconds: 1));
    }
  }

  Future<void> _playMacSystemSoundFor(Duration duration) async {
    // 使用 macOS 的 afplay 播放系统自带音效，并限制时长
    final int seconds = duration.inSeconds.clamp(1, 30);
    try {
      final result = await Process.run(
        'afplay',
        ['-t', seconds.toString(), _macSystemSoundPath],
      );
      if (result.exitCode != 0) {
        developer.log('afplay non-zero exit: ${result.exitCode} ${result.stderr}', name: 'NotificationService');
      }
    } catch (e, s) {
      developer.log('Failed to play macOS sound via afplay: $e', name: 'NotificationService', error: e, stackTrace: s);
    }
  }

  Future<void> _playMacSystemSoundMulti({required int times, required Duration singleDuration}) async {
    final int safeTimes = times.clamp(1, 10);
    for (int i = 0; i < safeTimes; i++) {
      await _playMacSystemSoundFor(singleDuration);
    }
  }
}


