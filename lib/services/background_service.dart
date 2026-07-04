
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Class quản lý foreground service để app chạy nền
class BackgroundService {
  /// Khởi tạo cấu hình foreground task
  static void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mic_loopback_channel',
        channelName: 'Mic Loopback Service',
        channelDescription: 'Keeps audio loopback running in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Bắt đầu foreground service
  static Future<void> start() async {
    await FlutterForegroundTask.startService(
      notificationTitle: '🎤 Mic Loopback đang chạy',
      notificationText: 'Âm thanh đang được truyền...',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(id: 'stop', text: 'Dừng'),
      ],
      callback: null, // Native handles audio, không cần callback
    );
  }

  /// Dừng foreground service
  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}
