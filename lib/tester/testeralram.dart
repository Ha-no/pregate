import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class TesterAlarmService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool isInitialized = false;

  TesterAlarmService({required this.flutterLocalNotificationsPlugin});

  // 알림 초기화
  Future<void> initialize() async {
    if (isInitialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );

    isInitialized = true;
  }

  // 테스트 알림 보내기
  Future<void> showTestNotification() async {
    if (!isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'test_channel_id',
      'Test Notifications',
      channelDescription: 'Channel for test notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      '테스트 알림',
      '알림 테스트 중...',
      platformChannelSpecifics,
    );
  }
}