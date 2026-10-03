import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../models/activity_session_model.dart';

class LocationTrackingData {
  final double totalDistanceMeters;
  final double currentSpeedKmh;
  final double averageSpeedKmh;
  final int durationSeconds;
  final List<GpsPointModel> routePoints;
  final bool isWeakGps;
  final String? statusMessage;

  const LocationTrackingData({
    this.totalDistanceMeters = 0.0,
    this.currentSpeedKmh = 0.0,
    this.averageSpeedKmh = 0.0,
    this.durationSeconds = 0,
    this.routePoints = const [],
    this.isWeakGps = false,
    this.statusMessage,
  });

  double get distanceKm => totalDistanceMeters / 1000.0;
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _durationTimer;
  final _trackingController = StreamController<LocationTrackingData>.broadcast();

  Stream<LocationTrackingData> get trackingStream => _trackingController.stream;

  // Session state
  String _currentSessionId = '';
  double _accumulatedDistanceMeters = 0.0;
  int _elapsedSeconds = 0;
  bool _isTracking = false;
  bool _isPaused = false;
  Position? _lastValidPosition;
  final List<GpsPointModel> _routePoints = [];

  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  double get totalDistanceMeters => _accumulatedDistanceMeters;
  int get elapsedSeconds => _elapsedSeconds;
  List<GpsPointModel> get routePoints => List.unmodifiable(_routePoints);

  // Check location permission
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  // Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  // Check if GPS is enabled on device
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Start tracking session
  Future<bool> startTracking(String sessionId) async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      _trackingController.add(const LocationTrackingData(
        statusMessage: 'Location services are disabled on your device. Please enable GPS.',
      ));
      return false;
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        _trackingController.add(const LocationTrackingData(
          statusMessage: 'Location permission was denied.',
        ));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _trackingController.add(const LocationTrackingData(
        statusMessage: 'Location permission is permanently denied. Please enable it in Settings.',
      ));
      return false;
    }

    // Reset session variables
    _currentSessionId = sessionId;
    _accumulatedDistanceMeters = 0.0;
    _elapsedSeconds = 0;
    _isTracking = true;
    _isPaused = false;
    _lastValidPosition = null;
    _routePoints.clear();

    // Timer for elapsed seconds
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _isTracking) {
        _elapsedSeconds++;
        _broadcastState();
      }
    });

    // Position Stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // Emit after moving 2 meters
    );

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handleNewPosition,
      onError: (e) {
        _trackingController.add(LocationTrackingData(
          totalDistanceMeters: _accumulatedDistanceMeters,
          durationSeconds: _elapsedSeconds,
          routePoints: _routePoints,
          statusMessage: 'GPS error: $e',
        ));
      },
    );

    _broadcastState();
    return true;
  }

  void _handleNewPosition(Position position) {
    if (!_isTracking || _isPaused) return;

    // Filter out weak GPS accuracy (threshold: 30m)
    final bool isWeak = position.accuracy > 30.0;
    if (isWeak && _lastValidPosition != null) {
      _trackingController.add(LocationTrackingData(
        totalDistanceMeters: _accumulatedDistanceMeters,
        durationSeconds: _elapsedSeconds,
        routePoints: _routePoints,
        isWeakGps: true,
        statusMessage: 'GPS accuracy is low. Move to an open area.',
      ));
      return;
    }

    if (_lastValidPosition != null) {
      final double distanceDelta = Geolocator.distanceBetween(
        _lastValidPosition!.latitude,
        _lastValidPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      final double timeDeltaSeconds = position.timestamp
          .difference(_lastValidPosition!.timestamp)
          .inMilliseconds / 1000.0;

      // Filter out impossible speed jumps (> 50 m/s = 180 km/h)
      final bool isImpossibleJump = timeDeltaSeconds > 0 && (distanceDelta / timeDeltaSeconds) > 50.0;

      if (!isImpossibleJump && distanceDelta >= 1.0) {
        _accumulatedDistanceMeters += distanceDelta;
      }
    }

    _lastValidPosition = position;

    final point = GpsPointModel(
      id: const Uuid().v4(),
      sessionId: _currentSessionId,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      speed: position.speed >= 0 ? position.speed : 0.0,
      timestamp: position.timestamp,
    );
    _routePoints.add(point);

    _broadcastState(currentSpeedMps: position.speed);
  }

  void _broadcastState({double currentSpeedMps = 0.0}) {
    final speedKmh = currentSpeedMps > 0 ? (currentSpeedMps * 3.6) : 0.0;
    final avgSpeedKmh = _elapsedSeconds > 0
        ? ((_accumulatedDistanceMeters / _elapsedSeconds) * 3.6)
        : 0.0;

    _trackingController.add(LocationTrackingData(
      totalDistanceMeters: _accumulatedDistanceMeters,
      currentSpeedKmh: speedKmh,
      averageSpeedKmh: avgSpeedKmh,
      durationSeconds: _elapsedSeconds,
      routePoints: List.unmodifiable(_routePoints),
      isWeakGps: false,
    ));
  }

  void pauseTracking() {
    _isPaused = true;
    _broadcastState();
  }

  void resumeTracking() {
    _isPaused = false;
    _broadcastState();
  }

  void stopTracking() {
    _isTracking = false;
    _isPaused = false;
    _durationTimer?.cancel();
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // DEBUG-ONLY GPS Simulation for development and testing
  void simulateDistanceInDebug(double distanceKm) {
    assert(() {
      _accumulatedDistanceMeters = distanceKm * 1000.0;
      _routePoints.clear();
      final now = DateTime.now();
      for (int i = 0; i <= 10; i++) {
        _routePoints.add(GpsPointModel(
          id: const Uuid().v4(),
          sessionId: _currentSessionId,
          latitude: 37.7749 + (i * 0.001 * (distanceKm / 2.0)),
          longitude: -122.4194 + (i * 0.001 * (distanceKm / 2.0)),
          altitude: 10.0,
          accuracy: 5.0,
          speed: 2.8,
          timestamp: now.add(Duration(seconds: i * 30)),
        ));
      }
      _broadcastState(currentSpeedMps: 2.8);
      return true;
    }());
  }

  void dispose() {
    stopTracking();
  }
}
