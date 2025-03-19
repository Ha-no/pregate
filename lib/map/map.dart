import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class MapView extends StatefulWidget {
  final Position? currentPosition;
  final bool isInside;
  final List<Map<String, double>> areaPoints;

  const MapView({
    super.key,
    required this.currentPosition,
    required this.isInside,
    required this.areaPoints,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? _controller;
  final Set<Polygon> _polygons = {};
  final Set<Marker> _markers = {};
  bool _mapInitialized = false;
  DateTime? _lastMapMovement;
  final bool _isAutoReturnEnabled = true;
  bool _userMovedMap = false; // 사용자가 지도를 직접 움직였는지 추적
  MapType _currentMapType = MapType.satellite; // 현재 맵 타입 상태 추가
  
  @override
  void initState() {
    super.initState();
    _initializeMapData();
    _startAutoReturnTimer();
  }
  
  void _startAutoReturnTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        if (_isAutoReturnEnabled && widget.currentPosition != null) {
          // 사용자가 지도를 직접 움직인 경우에만 3초 타이머 적용
          if (_userMovedMap) {
            if (_lastMapMovement != null && 
                DateTime.now().difference(_lastMapMovement!).inSeconds >= 3) {
              _returnToUserLocation();
              _userMovedMap = false; // 위치 복귀 후 상태 초기화
            }
          } else {
            // 사용자가 지도를 움직이지 않았다면 위치 변경 시 자동 추적
            _returnToUserLocation();
          }
        }
        _startAutoReturnTimer(); // 재귀적으로 타이머 계속 실행
      }
    });
  }
  
  void _returnToUserLocation() {
    if (_controller != null && widget.currentPosition != null) {
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          ),
          zoom:17.0,
        )),
      );
    }
  }
  
  // 맵 이동 기록 업데이트
  void _updateLastMovementTime() {
    setState(() {
      _lastMapMovement = DateTime.now();
      _userMovedMap = true; // 사용자가 지도를 직접 움직였음을 표시
    });
  }
  
  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 위치 정보가 변경된 경우에만 마커 업데이트
    if (widget.currentPosition != oldWidget.currentPosition) {
      _updateMarkerOnly();
      
      // 사용자가 지도를 직접 움직이지 않았다면 위치 변경 시 자동으로 따라가기
      if (!_userMovedMap && _controller != null) {
        _returnToUserLocation();
      }
    }
    
    // 내부/외부 상태가 변경된 경우에만 마커 색상 업데이트
    if (widget.isInside != oldWidget.isInside && widget.currentPosition != null) {
      _updateMarkerColor();
    }
    
    // 지정 구역이 변경된 경우에만 폴리곤 업데이트
    if (widget.areaPoints != oldWidget.areaPoints) {
      _updatePolygon();
    }
  }
  
  // 맵 초기화 시 한 번만 호출
  void _initializeMapData() {
    if (widget.currentPosition == null) return;
    
    _updateMarkerOnly();
    _updatePolygon();
    
    // 초기화 시에만 카메라 이동
    if (_controller != null && !_mapInitialized) {
      _controller!.animateCamera(
        CameraUpdate.newLatLng(LatLng(
          widget.currentPosition!.latitude,
          widget.currentPosition!.longitude,
        )),
      );
    }
    _mapInitialized = true;
  }
  
  // 마커 위치만 업데이트
  void _updateMarkerOnly() {
    if (widget.currentPosition == null) return;
    
    final LatLng position = LatLng(
      widget.currentPosition!.latitude,
      widget.currentPosition!.longitude,
    );
    
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: position,
          infoWindow: InfoWindow(
            title: '현재 위치',
            snippet: widget.isInside ? '지정 구역 내부' : '지정 구역 외부',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            widget.isInside ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
        ),
      );
    });
  }
  
  // 마커 색상만 업데이트
  void _updateMarkerColor() {
    if (widget.currentPosition == null) return;
    
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            widget.currentPosition!.latitude,
            widget.currentPosition!.longitude,
          ),
          infoWindow: InfoWindow(
            title: '현재 위치',
            snippet: widget.isInside ? '지정 구역 내부' : '지정 구역 외부',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            widget.isInside ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
        ),
      );
    });
  }
  
  // 폴리곤만 업데이트
  void _updatePolygon() {
    _polygons.clear();
    if (widget.areaPoints.isNotEmpty) {
      final List<LatLng> polygonPoints = [];
      
      if (widget.areaPoints.length == 4) {
        final sortedPoints = List<Map<String, double>>.from(widget.areaPoints);
        
        final minLat = sortedPoints.map((p) => p['lat']!).reduce(min);
        final maxLat = sortedPoints.map((p) => p['lat']!).reduce(max);
        final minLng = sortedPoints.map((p) => p['lng']!).reduce(min);
        final maxLng = sortedPoints.map((p) => p['lng']!).reduce(max);
        
        polygonPoints.add(LatLng(maxLat, minLng));
        polygonPoints.add(LatLng(maxLat, maxLng));
        polygonPoints.add(LatLng(minLat, maxLng));
        polygonPoints.add(LatLng(minLat, minLng));
        polygonPoints.add(LatLng(maxLat, minLng));
      } else {
        polygonPoints.addAll(widget.areaPoints
            .map((point) => LatLng(point['lat']!, point['lng']!))
            .toList());
      }
      
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('area_polygon'),
          points: polygonPoints,
          fillColor: Colors.blue.withOpacity(0.3),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    }
    
    setState(() {});
  }
  
  // 맵 타입 토글 함수 추가
  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.satellite 
          ? MapType.normal 
          : MapType.satellite;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              widget.currentPosition!.latitude,
              widget.currentPosition!.longitude,
            ),
            zoom: 17.0,
          ),
          markers: _markers,
          polygons: _polygons,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapType: _currentMapType, // 동적 맵 타입 적용
          onMapCreated: (GoogleMapController controller) {
            _controller = controller;
            if (!_mapInitialized) {
              _initializeMapData();
            }
            // 맵 스타일 강제 적용
            Future.delayed(const Duration(milliseconds: 200), () {
              if (_controller != null && mounted) {
                setState(() {}); // 맵 리렌더링 강제
              }
            });
          },
          onCameraMove: (_) {
            _updateLastMovementTime();
          },
          onCameraIdle: () {
            // 카메라 이동이 멈추면 마지막 이동 시간 업데이트
            _updateLastMovementTime();
          },
        ),
        // 맵 타입 토글 버튼 추가
        Positioned(
          top: 16,
          left: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: _toggleMapType,
            child: Icon(
              _currentMapType == MapType.satellite 
                  ? Icons.map 
                  : Icons.satellite,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}