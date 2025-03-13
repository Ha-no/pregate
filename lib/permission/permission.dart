import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

class Permission {
  final Function onPermissionGranted;
  final Function(String) onError;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  Permission({
    required this.onPermissionGranted,
    required this.onError,
    required this.flutterLocalNotificationsPlugin,
  });

  Future<void> initializePermissions() async {
    await _initializeNotifications();
    await _requestLocationPermission();
  }

  Future<void> _initializeNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError('위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
      return;
    }

    onPermissionGranted();
  }
}