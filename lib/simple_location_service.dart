import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:battery_plus/battery_plus.dart';
import 'package:traccar_client/main.dart';
import 'package:traccar_client/preferences.dart';

class SimpleLocationService {
  static Timer? _locationTimer;
  static bool _isTracking = false;
  static StreamSubscription<Position>? _positionStream;

  static Position? _lastSentPosition;
  static DateTime? _lastSentAt;

  static Timer? _coalesceTimer;
  static Position? _pendingLatest;

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

      await _positionStream?.cancel();
      if (Platform.isAndroid) {
        final settings = AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceMeters,
          forceLocationManager: true,
        );
        _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
          _handleStreamPosition,
          onError: (e) => developer.log('Stream error: $e'),
        );
      } else {
        final settings = LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceMeters,
        );
        _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen(
          _handleStreamPosition,
          onError: (e) => developer.log('Stream error: $e'),
        );
      }

      isTracking = true;
    } catch (error) {
      developer.log('Error starting tracking: $error');
      await _positionStream?.cancel();
      _positionStream = null;
      rethrow;
    }
  }

  /// Stop location tracking
  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    developer.log('Stopping location tracking (stream)');
    
    _locationTimer?.cancel();
    _locationTimer = null;
    
    await _positionStream?.cancel();
    _positionStream = null;

    _coalesceTimer?.cancel();
    _coalesceTimer = null;
    _pendingLatest = null;
    
    isTracking = false;
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
      if (!_shouldSend(p)) return;
      _pendingLatest = p;
      _coalesceTimer ??= Timer(const Duration(seconds: 2), () async {
        final toSend = _pendingLatest;
        _pendingLatest = null;
        _coalesceTimer?.cancel();
        _coalesceTimer = null;
        if (toSend != null) {
          await _sendLocationToServer(toSend);
          _lastSentPosition = toSend;
          _lastSentAt = DateTime.now();
        }
      });
    } catch (e) {
      developer.log('Error handling stream position: $e');
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

  /// Send location data to Traccar server
  static Future<void> _sendLocationToServer(Position position) async {
    try {
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
      };

      final url = Uri.parse('$serverUrl/?${_buildQueryString(locationData)}');
      
      developer.log('Sending location to: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Server request timeout', const Duration(seconds: 30));
        },
      );

      if (response.statusCode == 200) {
        developer.log('Location sent successfully');
      } else {
        developer.log('Server responded with status: ${response.statusCode}');
      }

    } catch (error) {
      developer.log('Error sending location to server: $error');
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
  
  /// Set tracking state with auto-enable check
  static set isTracking(bool value) {
    final oldValue = _isTracking;
    _isTracking = value;
    
    if (oldValue && !value) {
      final autoEnable = Preferences.instance.getBool(Preferences.autoEnableTracking) ?? true;
      if (autoEnable) {
        developer.log('Auto-enable tracking is enabled, scheduling restart from setter...');
        Timer(const Duration(seconds: 5), () async {
          developer.log('Auto-restarting tracking from setter...');
          try {
            await startTracking();
            developer.log('Tracking auto-restarted successfully from setter');
            _showAutoRestartNotification();
          } catch (error) {
            developer.log('Failed to auto-restart tracking from setter: $error');
          }
        });
      }
    }
  }
  
  /// Show notification that tracking was automatically restarted
  static void _showAutoRestartNotification() {
    try {
      if (messengerKey.currentState != null) {
        messengerKey.currentState!.showSnackBar(
          const SnackBar(
            content: Text('Tracking was automatically re-enabled'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      developer.log('Failed to show auto-restart notification: $error');
    }
  }

  /// Get current location status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      developer.log('Getting GPS position for status...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      developer.log('Status GPS position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
      return {
        'tracking': _isTracking,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      developer.log('Error getting GPS position for status: $error');
      return {
        'tracking': _isTracking,
        'error': error.toString(),
      };
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
      final serverUrl = Preferences.instance.getString(Preferences.url);
      final deviceId = Preferences.instance.getString(Preferences.id);
      
      if (serverUrl == null || deviceId == null) {
        developer.log('No server URL or device ID configured');
        return false;
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
      return response.statusCode == 200;
    } catch (error) {
      developer.log('Server connection test failed: $error');
      return false;
    }
  }
}
