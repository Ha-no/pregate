import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  DateTime? _lastLoggedTimestamp;
  int? _androidSdkVersion;

  // 안드로이드 SDK 버전 가져오기
  Future<int> get androidSdkVersion async {
    if (_androidSdkVersion != null) return _androidSdkVersion!;
    
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _androidSdkVersion = androidInfo.version.sdkInt;
        print('안드로이드 SDK 버전: $_androidSdkVersion');
        return _androidSdkVersion!;
      } catch (e) {
        print('기기 정보 가져오기 실패: $e');
        // 플러그인 오류 발생 시 기본값 반환 (Android 10 기준)
        _androidSdkVersion = 31;
        return _androidSdkVersion!;
      }
    }
    return 0; // 안드로이드가 아닌 경우
  }

  // 저장소 권한 확인 및 요청
  Future<bool> checkStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final sdkVersion = await androidSdkVersion;
        
        if (sdkVersion >= 33) { // Android 13 이상
          final status = await Permission.photos.status;
          if (status.isDenied) {
            final result = await Permission.photos.request();
            return result.isGranted;
          }
          return status.isGranted;
        } else if (sdkVersion >= 30) { // Android 11, 12
          final status = await Permission.manageExternalStorage.status;
          if (status.isDenied) {
            final result = await Permission.manageExternalStorage.request();
            return result.isGranted;
          }
          return status.isGranted;
        } else { // Android 10 이하
          final status = await Permission.storage.status;
          if (status.isDenied) {
            final result = await Permission.storage.request();
            return result.isGranted;
          }
          return status.isGranted;
        }
      } else if (Platform.isIOS) {
        return true; // iOS는 별도 권한 필요 없음
      }
      return false;
    } catch (e) {
      print('권한 확인 중 오류 발생: $e');
      return false;
    }
  }

  // 로그 파일 가져오기
  Future<File> _getLogFile() async {
    try {
      Directory? directory;
      
      if (Platform.isAndroid) {
        // 안드로이드 버전에 따라 적절한 저장소 경로 선택
        final sdkVersion = await androidSdkVersion;
        
        if (sdkVersion >= 30) { // Android 11 이상
          // 공용 문서 디렉토리 사용
          directory = Directory('/storage/emulated/0/Documents');
          // 디렉토리 존재 확인
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        } else {
          // Android 10 이하는 기존 방식 사용
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        throw UnsupportedError('지원되지 않는 플랫폼입니다.');
      }
      
      if (directory == null) {
        throw Exception('디렉토리를 찾을 수 없습니다.');
      }
      
      // 로그 디렉토리 생성
      final logDir = Directory('${directory.path}/gps_log');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      // 오늘 날짜로 파일명 생성
      final now = DateTime.now();
      final fileName = 'gps_log_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.txt';
      
      return File('${logDir.path}/$fileName');
    } catch (e) {
      print('로그 파일 생성 중 오류 발생: $e');
      rethrow;
    }
  }
  
  Future<void> logGpsData({
    required Position position,
    required bool isInside,
    required double distance,
  }) async {
    try {
      // 중복 로그 방지: 같은 타임스탬프의 위치 정보는 한 번만 기록
      if (_lastLoggedTimestamp != null && 
          _lastLoggedTimestamp == position.timestamp) {
        print('이미 로그된 위치 정보입니다. 로그 기록을 건너뜁니다.');
        return;
      }
      
      // 현재 로그 중인 타임스탬프 저장
      _lastLoggedTimestamp = position.timestamp;
      
      // 저장소 권한 확인
      final hasPermission = await checkStoragePermission();
      if (!hasPermission) {
        print('저장소 권한이 없습니다. 권한을 확인해주세요.');
        return;
      }
        
      final file = await _getLogFile();
      
      // 파일 존재 여부 확인 및 디버깅
      bool fileExists = await file.exists();
      print('파일 존재 여부: $fileExists');
      
      // JSON 형식으로 로그 데이터 구성
      final Map<String, dynamic> logData = {
        'Time': position.timestamp.add(const Duration(hours: 9)).toString().substring(0, 19),
        'Latitude': position.latitude.toStringAsFixed(6),
        'Longitude': position.longitude.toStringAsFixed(6),
        'Inside': isInside ? "1" : "0", // 1 : 내부, 0 : 외부
        'Distance': '${distance.toStringAsFixed(1)}m',
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'altitudeAccuracy': position.altitudeAccuracy,
        'heading': position.heading.toStringAsFixed(2),
        'headingAccuracy': position.headingAccuracy,
        'speed': position.speed.toStringAsFixed(2),
        'speedAccuracy': position.speedAccuracy,
      };

      String jsonLog = json.encode(logData);
      
      // 파일 쓰기 시도
      try {
        await file.writeAsString('$jsonLog\n', mode: FileMode.append);
        print('GPS 로그가 저장되었습니다: ${file.path}');
      } catch (e) {
        print('파일 쓰기 오류: $e');
        // 대체 방법으로 시도
        final bytes = utf8.encode('$jsonLog\n');
        await file.writeAsBytes(bytes, mode: FileMode.append);
        print('바이트 방식으로 GPS 로그가 저장되었습니다.');
      }
    } catch (e) {
      print('GPS 로그 저장 중 오류 발생: $e');
      print('오류 상세: ${e.toString()}');
    }
  }
}