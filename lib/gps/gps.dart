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
  final Function() onEnterRegion;
  StreamSubscription<Position>? positionStream;

  GPSService({
    required this.onPositionChanged,
    required this.onInsideChanged,
    required this.onDistanceChanged,
    required this.onTimeChanged,
    required this.onIntervalChanged,
    required this.onEnterRegion,
  });

  Future<void> startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }

    // 기존 스트림과 타이머 취소
    await positionStream?.cancel();
    locationTimer?.cancel();

    // 위치 스트림 설정
    positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: Duration(milliseconds: getGpsTime), // Android용 위치 업데이트 간격
      ),
    ).listen((Position position) {
      // 위치 업데이트 처리
      _handlePosition(position);
    });

    // 초기 위치 가져오기
    getCurrentPosition();
  }

  Future<void> getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // 현재 시간으로 타임스탬프 업데이트
      final updatedPosition = Position(
        longitude: position.longitude,
        latitude: position.latitude,
        timestamp: position.timestamp,  // 현재 시간으로 설정
        accuracy: position.accuracy,
        altitude: position.altitude,
        altitudeAccuracy: position.altitudeAccuracy,
        heading: position.heading,
        headingAccuracy: position.headingAccuracy,
        speed: position.speed,
        speedAccuracy: position.speedAccuracy,
      );

      distance = _calculateDistance(
        updatedPosition.latitude,
        updatedPosition.longitude,
        standardPoint['lat']!,
        standardPoint['lng']!,
      );

      int newGpsTime = _calculateUpdateInterval(distance);

      if (newGpsTime != getGpsTime) {
        getGpsTime = newGpsTime;
        onIntervalChanged(newGpsTime);
        startLocationTracking();
      }

      currentPosition = updatedPosition;
      
      bool isCurrentlyInside = _isPointInPolygon(
        updatedPosition.latitude,
        updatedPosition.longitude,
      );

      if (isCurrentlyInside && !isInside) {
        onEnterRegion();
      }

      isInside = isCurrentlyInside;
      if (isCurrentlyInside && !isInside) {
        NotificationUtils.showNotification(
          title: '영역 진입 알림', 
          body: '지정된 영역에 진입했습니다. 현재 시간: ${lastUpdateTime?.toString().substring(11, 19)}',
        );
      }
      
      // 콜백 실행
      onPositionChanged(updatedPosition);
      onInsideChanged(isInside);
      onDistanceChanged(distance);
      onTimeChanged(lastUpdateTime);
    } catch (e) {
      print('위치 획득 실패: $e');
    }
  }

  void _handlePosition(Position position) {

    print('타임 스탬프 : ${position.timestamp}');
    print('getGpsTime : $getGpsTime');

    distance = _calculateDistance(
      position.latitude,
      position.longitude,
      standardPoint['lat']!,
      standardPoint['lng']!,
    );

    int newGpsTime = _calculateUpdateInterval(distance);
    if (newGpsTime != getGpsTime) {
      getGpsTime = newGpsTime;
      onIntervalChanged(newGpsTime);
      // 간격이 변경되면 스트림 재시작
      startLocationTracking();
    }

    currentPosition = position;
    lastUpdateTime = position.timestamp;
    
    bool isCurrentlyInside = _isPointInPolygon(
      position.latitude,
      position.longitude,
    );

    if (isCurrentlyInside && !isInside) {
      onEnterRegion();
    }

    isInside = isCurrentlyInside;
    
    // 콜백 실행
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
    return 3600000;
  }

  bool _isPointInPolygon(double lat, double lng) {
    print("내부 영역 계산");
    double minLat = areaPoint.map((p) => p['lat']!).reduce(min);
    double maxLat = areaPoint.map((p) => p['lat']!).reduce(max);
    double minLng = areaPoint.map((p) => p['lng']!).reduce(min);
    double maxLng = areaPoint.map((p) => p['lng']!).reduce(max);

    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  @override
  void dispose() {
    positionStream?.cancel();
    locationTimer?.cancel();
  }
}

// 상수 정의
const Map<String, double> standardPoint = {
  'lat': 35.107770,
  'lng': 129.078880,
};

const List<Map<String, double>> areaPoint = [
  {'lat': 35.107760, 'lng': 129.079370},
  {'lat': 35.107751, 'lng': 129.081279},
  {'lat': 35.107495, 'lng': 129.079374},
  {'lat': 35.107479, 'lng': 129.081281},
];

const List<Map<String, double>> boundaryDistances = [
  {'distance': 200, 'time': 1000},
  {'distance': 3000, 'time': 60000},
  {'distance': 20000, 'time': 600000},
  {'distance': 50000, 'time': 1800000},
];