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
  StreamSubscription<Position>? positionStream;
  
  // 위치 정보 처리 중복 방지를 위한 변수 추가
  DateTime? _lastProcessedTimestamp;

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

    // 기존 스트림과 타이머 취소
    await positionStream?.cancel();
    locationTimer?.cancel();

    // 위치 스트림 설정
    positionStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: Duration(milliseconds: getGpsTime),
      ),
    ).listen((Position position) {
      _handlePosition(position);
    });

    getCurrentPosition();
  }

  Future<void> getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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

      // 위치 정보 처리는 _handlePosition 메서드로 통합
      _handlePosition(updatedPosition);
    } catch (e) {
      print('위치 획득 실패: $e');
    }
  }

  void _handlePosition(Position position) {
    print('타임 스탬프 : ${position.timestamp}');
    print('getGpsTime : $getGpsTime');
    
    // 이미 처리된 위치 정보인지 확인
    if (_lastProcessedTimestamp != null && 
        _lastProcessedTimestamp == position.timestamp) {
      print('이미 처리된 위치 정보입니다. 건너뜁니다.');
      return;
    }
    
    // 현재 처리 중인 타임스탬프 저장
    _lastProcessedTimestamp = position.timestamp;

    // 현재 위치 업데이트
    currentPosition = position;
    lastUpdateTime = position.timestamp;

    // 거리 계산 (한 번만 실행)
    distance = _calculateDistance(
      position.latitude,
      position.longitude,
      standardPoint['lat']!,
      standardPoint['lng']!,
    );

    // 내부 영역 계산 (한 번만 실행)
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
    
    // 업데이트 주기 계산 및 변경 (필요한 경우에만 스트림 재시작)
    int newGpsTime = _calculateUpdateInterval(distance);
    if (newGpsTime != getGpsTime) {
      getGpsTime = newGpsTime;
      onIntervalChanged(newGpsTime);
      // 비동기 실행으로 변경하여 현재 메서드 완료 후 실행되도록 함
      Future.microtask(() => startLocationTracking());
    }
    
    // 상태 업데이트는 마지막에 한 번만 실행
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
    positionStream?.cancel();
    locationTimer?.cancel();
  }
}

const Map<String, double> standardPoint = {
  'lat': 35.105800,
  'lng': 129.084600,
};

const List<Map<String, double>> areaPoint = [
  {'lat': 35.107760, 'lng': 129.079370},
  {'lat': 35.107751, 'lng': 129.081279},
  {'lat': 35.107495, 'lng': 129.079374},
  {'lat': 35.107479, 'lng': 129.081281},
];

const List<Map<String, double>> boundaryDistances = [
  {'distance': 1000, 'time': 1000},     // 1km - 1초
  {'distance': 5000, 'time': 60000},    // 5km - 1분
  {'distance': 15000, 'time': 600000},  // 15km - 10분 
                                        // 그외, 30분
];