import 'dart:io';
import 'dart:convert';  // json을 위해 추가
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  
  // 마지막으로 로그를 기록한 위치 정보의 타임스탬프
  DateTime? _lastLoggedTimestamp;
  
  factory LogService() {
    return _instance;
  }
  
  LogService._internal();
  
  Future<bool> checkStoragePermission() async {
    // 안드로이드 13 이상에서는 다른 권한 체계 사용
    if (Platform.isAndroid) {
      // Android 13 (API 33) 이상
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }
      
      // 권한 요청 - 더 강력한 권한 먼저 시도
      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        return true;
      }
      
      // 기본 저장소 권한 시도
      status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }
  
  Future<String> get _documentsPath async {
    // 안드로이드에서 외부 저장소 경로 가져오기
    if (Platform.isAndroid) {
      try {
        // 외부 저장소 루트 경로 직접 접근 시도
        Directory? externalDir;
        
        // 여러 경로 시도
        final List<Directory?> externalDirs = (await getExternalStorageDirectories()) as List<Directory?>;
        if (externalDirs.isNotEmpty && externalDirs[0] != null) {
          externalDir = externalDirs[0];
          
          // Android/data/패키지명 부분을 제거하고 Documents 폴더로 이동
          String path = externalDir!.path;  // null이 아님을 확신할 때는 ! 사용
          final List<String> pathSegments = path.split('/');
          final int androidIndex = pathSegments.indexOf('Android');
          
          if (androidIndex != -1) {
            // Android 폴더 이전까지의 경로 + Documents
            final String basePath = pathSegments.sublist(0, androidIndex).join('/');
            final documentsPath = '$basePath/Documents';
            
            final documentsDir = Directory(documentsPath);
            // 디렉토리가 없으면 생성
            if (!await documentsDir.exists()) {
              await documentsDir.create(recursive: true);
            }
            
            return documentsPath;
          }
        }
        
        // 대체 방법: 환경 변수에서 외부 저장소 경로 가져오기
        final String? externalStoragePath = Platform.environment['EXTERNAL_STORAGE'];
        if (externalStoragePath != null) {
          final documentsPath = '$externalStoragePath/Documents';
          final documentsDir = Directory(documentsPath);
          if (!await documentsDir.exists()) {
            await documentsDir.create(recursive: true);
          }
          print('환경 변수 외부 저장소 경로: $documentsPath');
          return documentsPath;
        }
      } catch (e) {
        print('외부 저장소 경로 가져오기 오류: $e');
      }
    }
    
    // 기본 문서 디렉토리 사용
    final directory = await getApplicationDocumentsDirectory();
    print('기본 문서 디렉토리 사용: ${directory.path}');
    return directory.path;
  }
  
  Future<File> _getLogFile() async {
    final documentsPath = await _documentsPath;
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd');
    final fileName = 'gps_log_${formatter.format(now)}.txt';
    
    // 로그 폴더 생성
    final logDir = Directory('$documentsPath/gps_logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    
    return File('${logDir.path}/$fileName');
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
      
      // JSON 형식으로 로그 데이터 구성
      final Map<String, dynamic> logData = {
        'Time': position.timestamp.toString().substring(0, 19),
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
      await file.writeAsString('$jsonLog\n', mode: FileMode.append);
      
      print('GPS 로그가 저장되었습니다: ${file.path}');
    } catch (e) {
      print('GPS 로그 저장 중 오류 발생: $e');
      print('오류 상세: ${e.toString()}');
    }
  }
}