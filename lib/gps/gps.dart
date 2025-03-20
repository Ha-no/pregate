import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import '../utils/utils.dart';

class GPSService {
  Position? currentPosition;
  bool isInside = false;
  double distance = 0;
  DateTime? lastUpdateTime;
  Timer? locationTimer;
  int getGpsTime = 1000;
  final Function(Position?) onPositionChanged;
  final Function(bool) onInsideChanged;
  final Function(double) onDistanceChanged;
  final Function(DateTime?) onTimeChanged;
  final Function(int) onIntervalChanged;

  GPSService({
    required this.onPositionChanged,
    required this.onInsideChanged,
    required this.onDistanceChanged,
    required this.onTimeChanged,
    required this.onIntervalChanged,
  });

  Future<void> startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }
   

    // 기존 타이머 취소
    locationTimer?.cancel();

    // Timer를 사용하여 주기적으로 위치 업데이트
    locationTimer = Timer.periodic(Duration(milliseconds: getGpsTime), (timer) {
      getCurrentPosition();
    });

    // 초기 위치 가져오기
    getCurrentPosition();
  }

  Future<void> getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final updatedPosition = Position(
        longitude: position.longitude,
        latitude: position.latitude,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        altitude: position.altitude,
        altitudeAccuracy: position.altitudeAccuracy,
        heading: position.heading,
        headingAccuracy: position.headingAccuracy,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy,
      );

      _handlePosition(updatedPosition);
    } catch (e) {
      print('위치 획득 실패: $e');
    }
  }

  void _handlePosition(Position position) {
    print('타임 스탬프 : ${position.timestamp}');
    print('getGpsTime : $getGpsTime');

    // 현재 위치 업데이트
    currentPosition = position;
    lastUpdateTime = position.timestamp.add(const Duration(hours: 9));

    // 거리 계산
    distance = _calculateDistance(
      position.latitude,
      position.longitude,
      standardPoint['lat']!,
      standardPoint['lng']!,
    );

    // 내부 영역 계산
    bool isCurrentlyInside = _isPointInPolygon(
      position.latitude,
      position.longitude,
    );

    // 영역 진입 알림 처리
    if (isCurrentlyInside && !isInside) {
      NotificationUtils.showNotification(
        title: '영역 진입 알림',
        body: '지정된 영역에 진입했습니다. 현재 시간: ${lastUpdateTime?.toString().substring(11, 19)}',
      );
    }
    
    isInside = isCurrentlyInside;
    
    // 업데이트 주기 계산 및 변경
    int newGpsTime = _calculateUpdateInterval(distance);
    if (newGpsTime != getGpsTime) {
      getGpsTime = newGpsTime;
      onIntervalChanged(newGpsTime);
      
      // Timer 재설정
      locationTimer?.cancel();
      locationTimer = Timer.periodic(Duration(milliseconds: getGpsTime), (timer) {
        getCurrentPosition();
      });
    }
    
    // 상태 업데이트
    onPositionChanged(position);
    onInsideChanged(isInside);
    onDistanceChanged(distance);
    onTimeChanged(lastUpdateTime);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    print("거리계산");
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  int _calculateUpdateInterval(double distance) {
    for (var boundary in boundaryDistances) {
      if (distance <= boundary['distance']!) {
        return boundary['time']!.toInt();
      }
    }
    return 1800000;
  }

  bool _isPointInPolygon(double lat, double lng) {
    print("내부 영역 계산");
    double minLat = areaPoint.map((p) => p['lat']!).reduce(min);
    double maxLat = areaPoint.map((p) => p['lat']!).reduce(max);
    double minLng = areaPoint.map((p) => p['lng']!).reduce(min);
    double maxLng = areaPoint.map((p) => p['lng']!).reduce(max);

    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  void dispose() {
    locationTimer?.cancel();
  }
}

const Map<String, double> standardPoint = {
  'lat': 35.1076275,
  'lng': 129.0803245,
};

// Test 용
// const Map<String, double> standardPoint = {
//   'lat': 35.174575,
//   'lng': 129.1282395,
// };

const List<Map<String, double>> areaPoint = [
  {'lat': 35.107760, 'lng': 129.079370},
  {'lat': 35.107760, 'lng': 129.081279},
  {'lat': 35.107495, 'lng': 129.079370},
  {'lat': 35.107495, 'lng': 129.081279},
];

// Test 용
// const List<Map<String, double>> areaPoint = [
//   {'lat': 35.174750, 'lng': 129.127879},
//   {'lat': 35.174400, 'lng': 129.127879},
//   {'lat': 35.174750, 'lng': 129.128600},
//   {'lat': 35.174400, 'lng': 129.128600},
// ];

const List<Map<String, double>> boundaryDistances = [
  {'distance': 1000, 'time': 1000},     // 1km - 1초
  {'distance': 5000, 'time': 60000},    // 5km - 1분
  {'distance': 15000, 'time': 600000},  // 15km - 10분 
                                        // 그외, 30분
];

// Test 용
// const List<Map<String, double>> boundaryDistances = [
//   {'distance': 100, 'time': 1000},   // 100m - 1초
//   {'distance': 150, 'time': 60000},   // 150m - 1분
//   {'distance': 200, 'time': 120000},   // 200m - 15초 
//   {'distance': 500, 'time': 180000},   // 200m - 15초 
// ];