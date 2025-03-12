import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Pregate Test App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Position? _currentPosition;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  // 내부 구역 좌표
  final List<Map<String, double>> boundaryPoints = [
    {'lat': 35.107760, 'lng': 129.079370}, // 좌상단
    {'lat': 35.107751, 'lng': 129.081279}, // 우상단
    {'lat': 35.107495, 'lng': 129.079374}, // 좌하단
    {'lat': 35.107479, 'lng': 129.081281}, // 우하단
  ];

  bool _isInside = false;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }


  // Hanho - 수정 필요
  Future<void> _checkAndRequestPermissions() async {
    // 위치 서비스 활성화 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorAndExit('위치 서비스를 활성화해주세요.');
      return;
    }

    // 위치 권한 확인 및 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorAndExit('위치 권한이 필요합니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorAndExit('설정에서 위치 권한을 허용해주세요.');
      return;
    }

    // 알림 권한 요청
    if (Platform.isIOS) {
      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      if (result != true) {
        _showErrorAndExit('알림 권한이 필요합니다.');
        return;
      }
    }
    
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      if (granted != true) {
        _showErrorAndExit('알림 권한이 필요합니다.');
        return;
      }
    }

    // 모든 권한이 허용되면 초기화 진행
    await _initializeNotifications();
    _startLocationTracking();
  }

  // 권한설정 실패 시, 앱 종료
  void _showErrorAndExit(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('권한 오류'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                SystemNavigator.pop(); // 앱 종료
              },
            ),
          ],
        );
      },
    );
  }

  // 푸시 알림 채널 설정
  Future<void> _initializeNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      'location_channel',
      '위치 알림',
      description: '위치 기반 알림을 위한 채널입니다.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MyHomePage(title: '위치 기반 알림'),
          ),
          (route) => false,
        );
      },
    );
  }

  bool _isPointInPolygon(double lat, double lng) {
    bool isInside = false;
    int j = boundaryPoints.length - 1;

    for (int i = 0; i < boundaryPoints.length; i++) {
      if ((boundaryPoints[i]['lng']! < lng && boundaryPoints[j]['lng']! >= lng ||
          boundaryPoints[j]['lng']! < lng && boundaryPoints[i]['lng']! >= lng) &&
          (boundaryPoints[i]['lat']! + (lng - boundaryPoints[i]['lng']!) /
              (boundaryPoints[j]['lng']! - boundaryPoints[i]['lng']!) *
              (boundaryPoints[j]['lat']! - boundaryPoints[i]['lat']!) < lat)) {
        isInside = !isInside;
      }
      j = i;
    }
    return isInside;
  }

  Future<void> _startLocationTracking() async {
    // 위치 서비스 활성화 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorAndExit('위치 서비스를 활성화해주세요.');
      return;
    }

    // 위치 권한 다시 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('백그라운드 위치 권한 필요'),
            content: const Text(
              '이 앱은 백그라운드에서도 위치 정보가 필요합니다.\n'
              '설정에서 위치 권한을 "항상 허용"으로 변경해주세요.'
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('설정으로 이동'),
                onPressed: () async {
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                  await Geolocator.openAppSettings();
                  // 설정에서 돌아왔을 때 권한 다시 체크
                  if (mounted) {
                    final newPermission = await Geolocator.checkPermission();
                    if (newPermission == LocationPermission.always) {
                      _startLocationTracking(); // 권한이 있으면 위치 추적 시작
                    } else {
                      _showErrorAndExit('백그라운드 위치 권한이 필요합니다.');
                    }
                  }
                },
              ),
              TextButton(
                child: const Text('종료'),
                onPressed: () {
                  SystemNavigator.pop(); // 앱 종료
                },
              ),
            ],
          );
        },
      );
      return;
    }

    // 위치정보 업데이트 주기
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // m 이상 이동시 업데이트
      timeLimit: null,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      
      bool isCurrentlyInside = _isPointInPolygon(
        position.latitude,
        position.longitude,
      );

      if (isCurrentlyInside && !_isInside) {
        _showNotification();
      }
      
      setState(() {
        _isInside = isCurrentlyInside;
      });
    });
  }

  Future<void> _showNotification() async {
    const androidChannel = AndroidNotificationChannel(
      'location_channel',
      '위치 알림',
      description: '위치 기반 알림을 위한 채널입니다.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      '위치 알림',
      '지정된 구역에 진입했습니다.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannel.id,
          androidChannel.name,
          channelDescription: androidChannel.description,
          importance: androidChannel.importance,
          priority: Priority.high,
          playSound: androidChannel.playSound,
          enableVibration: androidChannel.enableVibration,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('현재 위치:'),
            Text(
              _currentPosition != null
                  ? '위도: ${_currentPosition!.latitude.toStringAsFixed(6)}\n경도: ${_currentPosition!.longitude.toStringAsFixed(6)}'
                  : '위치 정보를 불러오는 중...',
            ),
            const SizedBox(height: 20),
            Text(
              '상태: ${_isInside ? "지정 구역 내부" : "지정 구역 외부"}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isInside ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '지정된 구역 좌표:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...boundaryPoints.map((point) => Text(
              '위도: ${point['lat']}, 경도: ${point['lng']}'
            )).toList(),
          ],
        ),
      ),
    );
  }
}