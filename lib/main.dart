import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
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
      ),
      home: const MyHomePage(title: '위치 기반 알림'),
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
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // 사각형 영역의 4개 꼭지점 정의 (예시 좌표)
  final List<Map<String, double>> boundaryPoints = [
    {'lat': 35.1077603, 'lng': 129.0793704}, // 좌상단
    {'lat': 35.1077511, 'lng': 129.0812786}, // 우상단
    {'lat': 35.1074950, 'lng': 129.0793740}, // 좌하단
    {'lat': 35.1074787, 'lng': 129.0812814}, // 우하단
  ];

  bool _isInside = false; // 영역 내부 여부 추적

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startLocationTracking();
  }

  Future<void> _initializeNotifications() async {
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // 점이 다각형 내부에 있는지 확인하는 함수
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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      
      // 현재 위치가 사각형 영역 안에 있는지 확인
      bool isCurrentlyInside = _isPointInPolygon(
        position.latitude,
        position.longitude,
      );

      // 영역에 처음 진입할 때만 알림 표시
      if (isCurrentlyInside && !_isInside) {
        _showNotification();
      }
      
      // 상태 업데이트
      setState(() {
        _isInside = isCurrentlyInside;
      });
    });
  }

  Future<void> _showNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iOSDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      '위치 알림',
      '지정된 구역에 진입했습니다!',
      details,
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
            Text('현재 위치:'),
            Text(
              _currentPosition != null
                  ? '위도: ${_currentPosition!.latitude}\n경도: ${_currentPosition!.longitude}'
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
            Text(
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