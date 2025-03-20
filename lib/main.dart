import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'permission/permission.dart';
import 'gps/gps.dart';
import 'utils/utils.dart';
import 'log/log.dart';
import 'map/map.dart';
import 'tester/testerlog.dart';
import 'tester/testeralram.dart';

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
  late final Permission permission;
  late final GPSService gpsService;
  late final LogService logService;
  late final TesterLogService testerLogService;
  late final TesterAlarmService testerAlarmService;

  Position? _currentPosition;
  bool _isInside = false;
  double distance = -1;
  DateTime? _lastUpdateTime;
  int _getGpsTime = 1000;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    
    logService = LogService();
    testerLogService = TesterLogService();
    
    testerLogService.addStateListener(() {
      setState(() {});
    });

    testerAlarmService = TesterAlarmService(
      flutterLocalNotificationsPlugin: FlutterLocalNotificationsPlugin(),
    );
    testerAlarmService.initialize();
    
    gpsService = GPSService(
      onPositionChanged: (position) {
        setState(() => _currentPosition = position);
      },
      onInsideChanged: (inside) => setState(() => _isInside = inside),
      onDistanceChanged: (dist) { 
        setState(() => distance = dist);
        if (distance != -1 && _currentPosition != null) {
          logService.logGpsData(
            position: _currentPosition!,
            isInside: _isInside,
            distance: distance,
          );
        }
      },
      onTimeChanged: (time) => setState(() => _lastUpdateTime = time),
      onIntervalChanged: (interval) => setState(() => _getGpsTime = interval),
    );
    
    permission = Permission(
      onPermissionGranted: gpsService.startLocationTracking,
      onError: (message) => ErrorUtils.showErrorDialog(context, message),
      flutterLocalNotificationsPlugin: NotificationUtils.flutterLocalNotificationsPlugin,
    );
    permission.initializePermissions();
  }
  
  @override
  void dispose() {
    gpsService.dispose();
    testerLogService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.33,
            width: double.infinity,
            child: _currentPosition != null
                ? MapView(
                    currentPosition: _currentPosition,
                    isInside: _isInside,
                    areaPoints: areaPoint,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          Expanded(
            child: Center(
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
                  // const Text(
                  //   '지정된 구역 좌표:',
                  //   style: TextStyle(fontWeight: FontWeight.bold),
                  // ),
                  // ...areaPoint.map((point) => Text(
                  //   '위도: ${point['lat']}, 경도: ${point['lng']}'
                  // )),
                  // const SizedBox(height: 20),
                  Text('정보 수집 시간 : ${_lastUpdateTime?.toString().substring(11, 19) ?? "없음"}'),
                  Text('기준점과의 거리 : ${(distance/1000).toStringAsFixed(1)} km'),
                  Text('GPS 정보 수집 주기 : '
                      '${(_getGpsTime / 3600000).toInt()}h : '
                      '${((_getGpsTime % 3600000) / 60000).toInt()}m : '
                      '${(((_getGpsTime % 3600000) % 60000) / 1000).toInt()}s'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        ElevatedButton(
                          onPressed: () {
                            testerAlarmService.showTestNotification();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('푸시 알림 테스트'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: gpsService.getCurrentPosition,
                          child: const Text('GPS 수동 업데이트'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          testerLogService.startLogging();
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('테스트 로깅 ON'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          testerLogService.stopLogging();
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('테스트 로깅 OFF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '테스트 로깅 상태: ${testerLogService.isLogging ? "ON" : "OFF"}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: testerLogService.isLogging ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}