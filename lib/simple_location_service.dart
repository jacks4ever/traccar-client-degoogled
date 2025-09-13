import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:io'; // Import for Platform class

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:battery_plus/battery_plus.dart';
import 'package:traccar_client/main.dart';
import 'package:traccar_client/preferences.dart';

// Ensure ForegroundService is defined or imported
class ForegroundService {
  static const MethodChannel _channel = MethodChannel('foreground_service');
  
  /// Start the foreground service
  static Future<bool> start() async {
    try {
      developer.log('Starting foreground service');
      final result = await _channel.invokeMethod('start');
      return result == true;
    } on PlatformException catch (e) {
      developer.log('Failed to start foreground service: ${e.message}');
      return false;
    } catch (e) {
      developer.log('Error starting foreground service: $e');
      return false;
    }
  }

  /// Stop the foreground service
  static Future<bool> stop() async {
    try {
      developer.log('Stopping foreground service');
      final result = await _channel.invokeMethod('stop');
      return result == true;
    } on PlatformException catch (e) {
      developer.log('Failed to stop foreground service: ${e.message}');
      return false;
    } catch (e) {
      developer.log('Error stopping foreground service: $e');
      return false;
    }
  }

  /// Check if the foreground service is running
  static Future<bool> isRunning() async {
    try {
      final result = await _channel.invokeMethod('isRunning');
      return result == true;
    } on PlatformException catch (e) {
      developer.log('Failed to check foreground service status: ${e.message}');
      return false;
    } catch (e) {
      developer.log('Error checking foreground service: $e');
      return false;
    }
  }
}

class SimpleLocationService {
  static Timer? _locationTimer;
  static bool _isTracking = false;
  static StreamSubscription<Position>? _positionStream;

  static Position? _lastSentPosition;
  static DateTime? _lastSentAt;
  static Position? _lastKnownPosition;
  static DateTime? _lastPositionTime;

  static Timer? _coalesceTimer;
  static Position? _pendingLatest;

  static Timer? _heartbeatTimer;
  static Timer? _freshGpsTimer;
  static int _failedRequestCount = 0;
  static const int _maxRetries = 3;
  static const int _freshGpsIntervalMinutes = 5; // Send fresh GPS every 5 minutes
  static const int _movementFreshGpsIntervalMinutes = 2; // More frequent when moving

  /// Check and request location permissions on app startup
  static Future<bool> requestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      developer.log('Location services are disabled');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        developer.log('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      developer.log('Location permissions are permanently denied');
      return false;
    }

    developer.log('Location permissions granted');
    return true;
  }

  /// Start continuous location tracking
  static Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      developer.log('Starting location tracking (stream)');

      final distanceMeters = Preferences.instance.getInt(Preferences.distance) ?? 75;
      final accuracyPref = Preferences.instance.getString(Preferences.accuracy) ?? 'medium';
      final accuracy = _mapAccuracy(accuracyPref);

      // Cancel any existing streams and timers
      await _positionStream?.cancel();
      _heartbeatTimer?.cancel();
      _coalesceTimer?.cancel();

      // Reset failure count
      _failedRequestCount = 0;

      if (Platform.isAndroid) {
        final settings = AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceMeters,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 5),
        );
        _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
          _handleStreamPosition,
          onError: _handleStreamError,
          onDone: _handleStreamDone,
        );
      } else {
        final settings = LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceMeters,
        );
        _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
          _handleStreamPosition,
          onError: _handleStreamError,
          onDone: _handleStreamDone,
        );
      }

      // Start foreground service for Android
      if (Platform.isAndroid) {
        await ForegroundService.start();
      }

      // Start heartbeat timer to ensure tracking stays alive
      _startHeartbeat();

      // Start fresh GPS timer to ensure regular fresh GPS readings
      _startFreshGpsTimer();

      // Send an immediate fresh GPS reading when tracking starts
      _sendFreshGpsReading();

      isTracking = true;
      developer.log('Location tracking started successfully');
    } catch (error) {
      developer.log('Error starting tracking: $error');
      await _cleanup();
      rethrow;
    }
  }

  /// Stop location tracking
  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    developer.log('Stopping location tracking (stream)');
    await _cleanup();
    isTracking = false;
  }

  /// Clean up all resources
  static Future<void> _cleanup() async {
    _locationTimer?.cancel();
    _locationTimer = null;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _freshGpsTimer?.cancel();
    _freshGpsTimer = null;

    await _positionStream?.cancel();
    _positionStream = null;

    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _pendingLatest = null;

    // Stop foreground service
    if (Platform.isAndroid) {
      await ForegroundService.stop();
    }
  }

  /// Send a single location update (for SOS or manual requests)
  static Future<void> sendSingleUpdate() async {
    await _getCurrentLocationAndSend();
  }

  /// Force a fresh GPS reading and send to server (clears any cached/test data)
  static Future<void> sendFreshGPSUpdate() async {
    try {
      developer.log('Forcing fresh GPS reading to clear any test data...');

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
        forceAndroidLocationManager: true,
      );

      developer.log('Fresh GPS position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');

      await _sendLocationToServer(position);

      developer.log('Fresh GPS update sent to server successfully');
    } catch (error) {
      developer.log('Error sending fresh GPS update: $error');
      rethrow;
    }
  }

  static void _handleStreamPosition(Position p) {
    try {
      // Always update last known position for status queries
      _lastKnownPosition = p;
      _lastPositionTime = DateTime.now();

      // Check if movement state changed and restart fresh GPS timer with appropriate interval
      final wasMoving = _lastSentPosition?.speed != null && _lastSentPosition!.speed > 1.0;
      final isMoving = p.speed > 1.0;

      if (wasMoving != isMoving) {
        developer.log('Movement state changed: ${wasMoving ? 'moving' : 'stationary'} -> ${isMoving ? 'moving' : 'stationary'}');
        _startFreshGpsTimer(); // Restart with new interval
      }

      if (!_shouldSend(p)) return;
      _pendingLatest = p;
      _coalesceTimer ??= Timer(const Duration(seconds: 2), () async {
        final toSend = _pendingLatest;
        _pendingLatest = null;
        _coalesceTimer?.cancel();
        _coalesceTimer = null;
        if (toSend != null) {
          await _sendLocationToServerWithRetry(toSend);
          _lastSentPosition = toSend;
          _lastSentAt = DateTime.now();
        }
      });
    } catch (e) {
      developer.log('Error handling stream position: $e');
    }
  }

  static void _handleStreamError(dynamic error) {
    developer.log('Location stream error: $error');
    // Try to restart the stream after a delay
    Timer(const Duration(seconds: 5), () {
      if (_isTracking) {
        developer.log('Attempting to restart location stream after error');
        startTracking();
      }
    });
  }

  static void _handleStreamDone() {
    developer.log('Location stream completed unexpectedly');
    // Try to restart the stream if we're supposed to be tracking
    if (_isTracking) {
      Timer(const Duration(seconds: 3), () {
        if (_isTracking) {
          developer.log('Restarting location stream after completion');
          startTracking();
        }
      });
    }
  }

  /// Start heartbeat timer to keep tracking alive
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isTracking) {
        developer.log('Heartbeat: Location tracking still active');
        // Send a heartbeat to server to keep connection alive
        _sendHeartbeat();
      } else {
        timer.cancel();
      }
    });
  }

  /// Start fresh GPS timer to ensure regular fresh GPS readings
  static void _startFreshGpsTimer() {
    _freshGpsTimer?.cancel();

    // Determine interval based on movement state
    final isMoving = _lastKnownPosition?.speed != null && _lastKnownPosition!.speed > 1.0; // > 1 m/s
    final intervalMinutes = isMoving ? _movementFreshGpsIntervalMinutes : _freshGpsIntervalMinutes;

    _freshGpsTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) {
      if (_isTracking) {
        developer.log('Fresh GPS timer: Requesting fresh GPS reading');
        _sendFreshGpsReading();

        // Restart timer with potentially different interval based on current movement
        _startFreshGpsTimer();
      } else {
        timer.cancel();
      }
    });

    developer.log('Fresh GPS timer started with ${intervalMinutes}min interval');
  }

  /// Send a fresh GPS reading to server (bypasses normal filtering)
  static Future<void> _sendFreshGpsReading() async {
    try {
      developer.log('Getting fresh GPS position for continuous tracking...');

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
        forceAndroidLocationManager: true,
      );

      developer.log('Fresh GPS position obtained: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m, speed: ${position.speed}m/s)');

      // Always send fresh GPS readings regardless of filtering rules
      await _sendLocationToServerWithRetry(position);

      // Update cached position
      _lastKnownPosition = position;
      _lastPositionTime = DateTime.now();

      developer.log('Fresh GPS reading sent to server successfully');
    } catch (error) {
      developer.log('Error getting fresh GPS reading: $error');

      // If fresh GPS fails, try to send cached position if available
      if (_lastKnownPosition != null) {
        developer.log('Sending cached position as fallback');
        await _sendLocationToServerWithRetry(_lastKnownPosition!);
      }
    }
  }

  /// Send heartbeat to server (includes location data if available)
  static Future<void> _sendHeartbeat() async {
    try {
      final serverUrl = Preferences.instance.getString(Preferences.url);
      final deviceId = Preferences.instance.getString(Preferences.id);

      if (serverUrl == null || deviceId == null) return;

      // Try to get current position for heartbeat, but don't wait too long
      Position? currentPosition;
      try {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        ).timeout(const Duration(seconds: 8));

        developer.log('Heartbeat with fresh GPS: ${currentPosition.latitude}, ${currentPosition.longitude}');
      } catch (e) {
        // Use cached position if fresh GPS fails
        currentPosition = _lastKnownPosition;
        developer.log('Heartbeat using cached position: ${currentPosition?.latitude}, ${currentPosition?.longitude}');
      }

      Map<String, dynamic> heartbeatData;

      if (currentPosition != null) {
        // Send heartbeat with location data
        final battery = Battery();
        int batteryLevel = 0;
        try {
          batteryLevel = await battery.batteryLevel;
        } catch (e) {
          developer.log('Failed to get battery level for heartbeat: $e');
        }

        heartbeatData = {
          'id': deviceId,
          'lat': currentPosition.latitude,
          'lon': currentPosition.longitude,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'altitude': currentPosition.altitude,
          'speed': currentPosition.speed,
          'bearing': currentPosition.heading,
          'accuracy': currentPosition.accuracy,
          'batt': batteryLevel,
          'battery': batteryLevel,
          'heartbeat': true, // Mark as heartbeat
        };

        // Update cached position
        _lastKnownPosition = currentPosition;
        _lastPositionTime = DateTime.now();
      } else {
        // Send basic heartbeat without location
        heartbeatData = {
          'id': deviceId,
          'heartbeat': DateTime.now().millisecondsSinceEpoch,
        };
      }

      final url = Uri.parse('$serverUrl/?${_buildQueryString(heartbeatData)}');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Heartbeat timeout', const Duration(seconds: 10));
        },
      );

      if (response.statusCode == 200) {
        developer.log('Heartbeat sent successfully ${currentPosition != null ? 'with location data' : 'without location'}');
      }
    } catch (error) {
      developer.log('Heartbeat failed: $error');
    }
  }

  static bool _shouldSend(Position current) {
    final isHighestAccuracy = (Preferences.instance.getString(Preferences.accuracy) ?? 'medium') == 'highest';
    final distanceFilter = Preferences.instance.getInt(Preferences.distance) ?? 0;
    final intervalFilter = Preferences.instance.getInt(Preferences.interval) ?? 0;
    final fastestInterval = Preferences.instance.getInt(Preferences.fastestInterval);

    if (_lastSentPosition == null) return true;

    final last = _lastSentPosition!;
    final now = DateTime.now();
    final since = _lastSentAt != null ? now.difference(_lastSentAt!).inSeconds : 1 << 30;

    if (!isHighestAccuracy && fastestInterval != null && since < fastestInterval) return false;

    final dist = _haversine(last.latitude, last.longitude, current.latitude, current.longitude);

    if (distanceFilter > 0 && dist >= distanceFilter) return true;

    if (distanceFilter == 0 || isHighestAccuracy) {
      if (intervalFilter > 0 && since >= intervalFilter) return true;
    }

    final angleFilter = Preferences.instance.getInt(Preferences.angle) ?? 0;
    final lastHeading = last.heading;
    final currHeading = current.heading;
    if (isHighestAccuracy && angleFilter > 0 && lastHeading >= 0 && currHeading >= 0) {
      final angle = (currHeading - lastHeading).abs();
      if (angle >= angleFilter) return true;
    }

    return false;
  }

  static LocationAccuracy _mapAccuracy(String pref) {
    switch (pref) {
      case 'highest':
        return LocationAccuracy.best;
      case 'medium':
        return LocationAccuracy.high;
      case 'low':
        return LocationAccuracy.low;
      default:
        return LocationAccuracy.high;
    }
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371008.8;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final a = sinLat * sinLat + math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * sinLon * sinLon;
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double degree) => degree * math.pi / 180.0;

  /// Get current location and send to server
  static Future<void> _getCurrentLocationAndSend() async {
    try {
      developer.log('Getting current GPS position (single-shot)...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      developer.log('GPS position obtained: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
      await _sendLocationToServer(position);
    } catch (error) {
      developer.log('Error getting location: $error');
    }
  }

  /// Send location data to Traccar server with retry mechanism
  static Future<void> _sendLocationToServerWithRetry(Position position) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await _sendLocationToServer(position);
        _failedRequestCount = 0; // Reset on success
        return;
      } catch (error) {
        developer.log('Location send attempt $attempt failed: $error');
        _failedRequestCount++;

        if (attempt < _maxRetries) {
          // Wait before retry with exponential backoff
          final delay = Duration(seconds: math.pow(2, attempt).toInt());
          await Future.delayed(delay);
        }
      }
    }

    developer.log('Failed to send location after $_maxRetries attempts');

    // If we've failed too many times, consider restarting the stream
    if (_failedRequestCount > 10) {
      developer.log('Too many failed requests, restarting location stream');
      _failedRequestCount = 0;
      if (_isTracking) {
        await stopTracking();
        await Future.delayed(const Duration(seconds: 5));
        await startTracking();
      }
    }
  }

  /// Send location data to Traccar server
  static Future<void> _sendLocationToServer(Position position) async {
    final serverUrl = Preferences.instance.getString(Preferences.url);
    final deviceId = Preferences.instance.getString(Preferences.id);

    if (serverUrl == null || deviceId == null) {
      developer.log('Server URL or device ID not configured');
      return;
    }

    final battery = Battery();
    int batteryLevel = 0;
    try {
      batteryLevel = await battery.batteryLevel;
    } catch (e) {
      developer.log('Failed to get battery level: $e');
    }

    final locationData = {
      'id': deviceId,
      'lat': position.latitude,
      'lon': position.longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'altitude': position.altitude,
      'speed': position.speed,
      'bearing': position.heading,
      'accuracy': position.accuracy,
      'batt': batteryLevel,
      'battery': batteryLevel,
    };

    final url = Uri.parse('$serverUrl/?${_buildQueryString(locationData)}');

    developer.log('Sending location to: $url');

    final response = await http.get(url).timeout(
      const Duration(seconds: 15), // Reduced timeout
      onTimeout: () {
        throw TimeoutException('Server request timeout', const Duration(seconds: 15));
      },
    );

    if (response.statusCode == 200) {
      developer.log('Location sent successfully');
    } else {
      throw Exception('Server responded with status: ${response.statusCode}');
    }
  }

  /// Build query string for HTTP request
  static String _buildQueryString(Map<String, dynamic> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  /// Check if currently tracking
  static bool get isTracking => _isTracking;

  /// Set tracking state
  static set isTracking(bool value) {
    _isTracking = value;
  }

  /// Get cached location status (no GPS request)
  static Future<Map<String, dynamic>> getCachedStatus() async {
    if (_lastKnownPosition != null && _lastPositionTime != null) {
      final age = DateTime.now().difference(_lastPositionTime!).inSeconds;
      return {
        'tracking': _isTracking,
        'latitude': _lastKnownPosition!.latitude,
        'longitude': _lastKnownPosition!.longitude,
        'accuracy': _lastKnownPosition!.accuracy,
        'timestamp': _lastPositionTime!.toIso8601String(),
        'age_seconds': age,
      };
    } else {
      return {
        'tracking': _isTracking,
        'error': 'No location data available',
      };
    }
  }

  /// Get current location status (makes fresh GPS request)
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      developer.log('Getting GPS position for status...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      developer.log('Status GPS position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy})');

      // Update cached position
      _lastKnownPosition = position;
      _lastPositionTime = DateTime.now();

      return {
        'tracking': _isTracking,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.toIso8601String(),
      };
    } catch (error) {
      developer.log('Error getting GPS position for status: $error');
      // Return cached status if available
      if (_lastKnownPosition != null && _lastPositionTime != null) {
        final age = DateTime.now().difference(_lastPositionTime!).inSeconds;
        return {
          'tracking': _isTracking,
          'latitude': _lastKnownPosition!.latitude,
          'longitude': _lastKnownPosition!.longitude,
          'accuracy': _lastKnownPosition!.accuracy,
          'timestamp': _lastPositionTime!.toIso8601String(),
          'age_seconds': age,
          'error': 'Using cached location: ${error.toString()}',
        };
      } else {
        return {
          'tracking': _isTracking,
          'error': error.toString(),
        };
      }
    }
  }

  /// Test server connection
  static Future<Map<String, dynamic>> testServerConnectionDetailed() async {
    try {
      final serverUrl = Preferences.instance.getString(Preferences.url);
      final deviceId = Preferences.instance.getString(Preferences.id);

      if (serverUrl == null || deviceId == null) {
        developer.log('No server URL or device ID configured');
        return {
          'connected': false,
          'message': 'Server not configured',
          'serverUrl': null,
        };
      }

      final testData = {
        'id': deviceId,
        'test': 'connection',
      };

      final url = Uri.parse('$serverUrl/?${_buildQueryString(testData)}');
      developer.log('Testing connection to: $url');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection test timeout', const Duration(seconds: 10));
        },
      );

      developer.log('Server connection test: ${response.statusCode}');
      final connected = response.statusCode == 200;

      final uri = Uri.parse(serverUrl);
      final serverHost = uri.host + (uri.hasPort ? ':${uri.port}' : '');

      return {
        'connected': connected,
        'message': connected
            ? 'Connected to $serverHost'
            : 'Failed to connect to $serverHost (HTTP ${response.statusCode})',
        'serverUrl': serverUrl,
        'statusCode': response.statusCode,
      };
    } catch (error) {
      developer.log('Server connection test failed: $error');
      final serverUrl = Preferences.instance.getString(Preferences.url);
      final uri = serverUrl != null ? Uri.parse(serverUrl) : null;
      final serverHost = uri != null ? uri.host + (uri.hasPort ? ':${uri.port}' : '') : 'server';

      String errorMessage;
      if (error is TimeoutException || error.toString().contains('timeout')) {
        errorMessage = 'Connection timeout to $serverHost';
      } else if (error.toString().contains('SocketException') || error.toString().contains('Network')) {
        errorMessage = 'Network error to $serverHost';
      } else {
        errorMessage = 'Cannot reach $serverHost';
      }

      return {
        'connected': false,
        'message': errorMessage,
        'serverUrl': serverUrl,
        'error': error.toString(),
      };
    }
  }

  /// Test server connection (legacy method for backward compatibility)
  static Future<bool> testServerConnection() async {
    try {
      final result = await testServerConnectionDetailed();
      return result['connected'] as bool;
    } catch (e) {
      developer.log('Error testing server connection', error: e);
      return false;
    }
  }
}
