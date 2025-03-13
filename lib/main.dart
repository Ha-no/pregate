import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'permission/permission.dart';
import 'gps/gps.dart';
import 'utils/utils.dart';
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
  // Import 모듈
  late final Permission permission;
  late final GPSService gpsService;  // GPS 서비스 추가

  Position? _currentPosition; // 현재 위치 정보
  bool _isInside = false;     // 내부 진입 확인
  double distance = 0;        // 현재 위치와 표준 지점 사이의 거리 
  DateTime? _lastUpdateTime;  // 마지막 위치 업데이트 시간
  int _getGpsTime = 1000;     // 초기 GPS 업데이트 주기 (1초)
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    
    // GPS 서비스 초기화
    gpsService = GPSService(
      onPositionChanged: (position) => setState(() => _currentPosition = position),
      onInsideChanged: (inside) => setState(() => _isInside = inside),
      onDistanceChanged: (dist) => setState(() => distance = dist),
      onTimeChanged: (time) => setState(() => _lastUpdateTime = time),
      onIntervalChanged: (interval) => setState(() => _getGpsTime = interval),
      onEnterRegion: () => NotificationUtils.showNotification(),
    );
    
    permission = Permission(
      onPermissionGranted: _startLocationTracking,
      onError: (message) => ErrorUtils.showErrorDialog(context, message),
      flutterLocalNotificationsPlugin: NotificationUtils.flutterLocalNotificationsPlugin,
    );
    permission.initializePermissions();
  }
  
  @override
  void dispose() {
    gpsService.dispose();  // GPS 서비스 정리
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    try {
      await gpsService.startLocationTracking();
    } catch (e) {
      ErrorUtils.showErrorDialog(context, '위치 서비스를 활성화해주세요.');
    }
  }

  Future<void> _getCurrentPosition() async {
    await gpsService.getCurrentPosition();
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
            Text('정보 수집 시간 : ${_lastUpdateTime?.toString().substring(11, 19) ?? "없음"}'),
            Text('거리 정보 : ${distance.toStringAsFixed(1)}m'),
            Text('GPS 정보 수집 주기 : '
                '${(_getGpsTime / 1000).toStringAsFixed(1)}s / '
                '${(_getGpsTime / 60000).toStringAsFixed(1)}m / '
                '${(_getGpsTime / 3600000).toStringAsFixed(1)}h'),
            ElevatedButton(
              onPressed: _getCurrentPosition,
              child: const Text('GPS 수동 업데이트'),
            ),
          ],
        ),
      ),
    );
  }
}