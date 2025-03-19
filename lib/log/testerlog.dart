import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class TesterLogService {
  static final TesterLogService _instance = TesterLogService._internal();
  factory TesterLogService() => _instance;
  TesterLogService._internal();

  Timer? _logTimer;
  bool _isLogging = false;
  int? _androidSdkVersion;
  File? _logFile;
  final List<Function()> _stateListeners = [];
  int? _logCount = 1;

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
        // 플러그인 오류 발생 시 기본값 반환
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
  // 상태 리스너 추가 메서드
  void addStateListener(Function() listener) {
    _stateListeners.add(listener);
  }

  // 로그 파일 가져오기
  Future<File> _getTestLogFile() async {
    if (_logFile != null) return _logFile!;
    
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
        _logCount = 1;
        await logDir.create(recursive: true);
      }
      
      // 오늘 날짜로 파일명 생성
      final now = DateTime.now();
      final fileName = 'Tester_gps_log_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.txt';
      
      return File('${logDir.path}/$fileName');
    } catch (e) {
      print('테스트 로그 파일 생성 중 오류 발생: $e');
      rethrow;
    }
  }
  
  // 테스트 로깅 시작
  Future<void> startLogging() async {
    if (_isLogging) return; // 이미 로깅 중이면 중복 실행 방지
    
    _isLogging = true;
    print('테스트 로깅 시작');
    
    // 저장소 권한 확인
    final hasPermission = await checkStoragePermission();
    if (!hasPermission) {
      print('저장소 권한이 없습니다. 권한을 확인해주세요.');
      _isLogging = false;
      return;
    }
    
    // 로그 파일 준비
    final file = await _getTestLogFile();

    await file.writeAsString('\n', mode: FileMode.append);
    await file.writeAsString('Tester Loger $_logCount Start ############################################ \n',
                              mode: FileMode.append);
    
    _logCount = _logCount! + 1;

    print('테스트 로그 파일 경로: ${file.path}');
        
    // 1초마다 위치 정보 기록
    _logTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isLogging) {
        timer.cancel();
        return;
      }
      
      try {
        // 현재 위치 가져오기
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 2),
        );
        
        // 로그 데이터 구성
        final Map<String, dynamic> logData = {
          'Time': DateTime.now().toString().substring(0, 23),
          'Latitude': position.latitude.toStringAsFixed(6),
          'Longitude': position.longitude.toStringAsFixed(6),
          'Accuracy': position.accuracy.toStringAsFixed(1),
          'Altitude': position.altitude.toStringAsFixed(1),
          'Speed': position.speed.toStringAsFixed(2),
          'Heading': position.heading.toStringAsFixed(2),
        };
        
        String jsonLog = json.encode(logData);
        
        // 파일에 로그 추가
        await file.writeAsString('$jsonLog\n', mode: FileMode.append);
        print('GPS 테스터 로그가 저장되었습니다: ${file.path}');
      } catch (e) {
        print('테스트 로그 기록 중 오류 발생: $e');
      }
    });
  }
  
  // 테스트 로깅 중지
  Future<void> stopLogging() async {
    if (!_isLogging) return;
    
    _isLogging = false;
    _logTimer?.cancel();
    _logTimer = null;
    
    print('테스트 로깅 중지');
  }
  
  // 현재 로깅 상태 반환
  bool get isLogging => _isLogging;
  
  // 리소스 해제
  void dispose() {
    stopLogging();
  }
}