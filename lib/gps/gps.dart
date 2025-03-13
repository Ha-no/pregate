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
    locationTimer?.cancel();

    locationTimer = Timer.periodic(
        Duration(milliseconds: getGpsTime), (timer) => getCurrentPosition());
  }

  Future<void> getCurrentPosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      distance = _calculateDistance(
        position.latitude,
        position.longitude,
        StandardPoint['lat']!,
        StandardPoint['lng']!,
      );

      int newGpsTime = _calculateUpdateInterval(distance);

      if (newGpsTime != getGpsTime) {
        getGpsTime = newGpsTime;
        onIntervalChanged(newGpsTime);
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
      if (isCurrentlyInside && !isInside) {
        NotificationUtils.showNotification(
      title: '영역 진입 알림', 
      body: '지정된 영역에 진입했습니다. 현재 시간: ${lastUpdateTime?.toString().substring(11, 19)}',);
      }
      
      // 콜백 실행
      onPositionChanged(position);
      onInsideChanged(isInside);
      onDistanceChanged(distance);
      onTimeChanged(lastUpdateTime);
    } catch (e) {
      print('위치 획득 실패: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
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
    double minLat = AreaPoint.map((p) => p['lat']!).reduce(min);
    double maxLat = AreaPoint.map((p) => p['lat']!).reduce(max);
    double minLng = AreaPoint.map((p) => p['lng']!).reduce(min);
    double maxLng = AreaPoint.map((p) => p['lng']!).reduce(max);

    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  void dispose() {
    locationTimer?.cancel();
  }
}

// 상수 정의
const Map<String, double> StandardPoint = {
  'lat': 35.107770,
  'lng': 129.078880,
};

const List<Map<String, double>> AreaPoint = [
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