import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

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

// 앱 관련 변수
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// 동작 관련 변수
class _MyHomePageState extends State<MyHomePage> {
  Position? _currentPosition; // 현재 위치 정보
  bool _isInside = false;     // 내부 진입 확인
  double distance = 0;        // 현재 위치와 표준 지점 사이의 거리 
  DateTime? _lastUpdateTime;  // 마지막 위치 업데이트 시간
  Timer? _locationTimer;      // 위치 확인 타이머
  int _getGpsTime = 1000;     // 초기 GPS 업데이트 주기 (1초)
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorAndExit('위치 권한이 거부되었습니다.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorAndExit('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
      return;
    }

    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorAndExit('위치 서비스를 활성화해주세요.');
      return;
    }

    // 기존 타이머가 있다면 취소
    _locationTimer?.cancel();

    // _getGpsTime 간격으로 위치 확인
    _locationTimer = Timer.periodic(Duration(milliseconds: _getGpsTime), (
      timer,
    ) {
      _getCurrentPosition();
    });
  }

  Future<void> _getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // StandardPoint와의 거리 계산
      distance = _calculateDistance(
        position.latitude,
        position.longitude,
        StandardPoint['lat']!,
        StandardPoint['lng']!
      );

      // 거리에 따른 새로운 GPS 업데이트 주기 계산
      int newGpsTime = _calculateUpdateInterval(distance);
      
      // GPS 업데이트 주기가 변경되었다면 위치 추적을 재시작
      if (newGpsTime != _getGpsTime) {
        setState(() {
          _getGpsTime = newGpsTime;
        });
        _startLocationTracking();
      }

      setState(() {
        _currentPosition = position;
        _lastUpdateTime = DateTime.now();
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
    } catch (e) {
      print('위치 획득 실패: $e');
    }
  }

  // 두 지점 사이의 거리 계산 함수 (m)
  double _calculateDistance( double lat1, double lon1, double lat2, double lon2 ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // 거리에 따른 GPS 업데이트 주기 계산 함수 (ms)
  int _calculateUpdateInterval(double distance) {
    for (var boundary in boundaryDistances) {
      if (distance <= boundary['distance']!) {
        return boundary['time']!.toInt();
      }
    }

    return 3600000;
  }

  // Boundary 내부 진입 여부 확인 함수
  bool _isPointInPolygon(double lat, double lng) {
    int intersectCount = 0;
    for (int i = 0; i < AreaPoint.length; i++) {
      int j = (i + 1) % AreaPoint.length;

      if ((AreaPoint[i]['lng']! <= lng && lng < AreaPoint[j]['lng']!) ||
          (AreaPoint[j]['lng']! <= lng && lng < AreaPoint[i]['lng']!)) {
        double intersectLat =
            (AreaPoint[j]['lat']! - AreaPoint[i]['lat']!) *
                (lng - AreaPoint[i]['lng']!) /
                (AreaPoint[j]['lng']! - AreaPoint[i]['lng']!) +
            AreaPoint[i]['lat']!;

        if (lat < intersectLat) {
          intersectCount++;
        }
      }
    }
    return intersectCount % 2 == 1;
  }

  // 알림 표시 함수
  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'location_channel',
          '위치 알림',
          channelDescription: '지정된 영역 진입 시 알림',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      '영역 진입',
      '지정된 영역에 진입했습니다.',
      platformChannelSpecifics,
    );
  }

  // 오류 메시지 표시 및 앱 종료 함수
  void _showErrorAndExit(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
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
            ...AreaPoint.map((point) => Text(
              '위도: ${point['lat']}, 경도: ${point['lng']}'
            )),
            const SizedBox(height: 20),
            Text('정보 수집 시간 : ${_lastUpdateTime?.toString().substring(11, 19)}'),
            Text('거리 정보 : ${distance.toStringAsFixed(1)}m'),
            Text('GPS 정보 수집 주기 : '
                '${(_getGpsTime / 1000).toStringAsFixed(1)}s / '
                '${(_getGpsTime / 60000).toStringAsFixed(1)}m / '
                '${(_getGpsTime / 3600000).toStringAsFixed(1)}h'),
          ],
        ),
      ),
    );
  }
}

// 표준 지점 정의
const Map<String, double> StandardPoint = {
  'lat': 35.107770, // 예시 위도
  'lng': 129.078880, // 예시 경도
};

// 다각형 꼭지점 정의
const List<Map<String, double>> AreaPoint = [
  {'lat': 35.107760, 'lng': 129.079370}, // 좌상단
  {'lat': 35.107751, 'lng': 129.081279}, // 우상단
  {'lat': 35.107495, 'lng': 129.079374}, // 좌하단
  {'lat': 35.107479, 'lng': 129.081281}, // 우하단
];

// 위치 거리 기준 (m, ms)
const List<Map<String, double>> boundaryDistances = [
  {'distance': 200, 'time': 1000},      // 200m 이내 1초
  {'distance': 3000, 'time': 60000},    // 3000m 이내 1분
  {'distance': 20000, 'time': 600000},  // 20000m 이내 10분
  {'distance': 50000, 'time': 1800000}, // 50000m 이내 30분
];
