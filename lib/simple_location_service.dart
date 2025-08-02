import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:traccar_client/preferences.dart';

class SimpleLocationService {
  static Timer? _locationTimer;
  static bool _isTracking = false;
  static StreamSubscription<Position>? _positionStream;

  /// Check and request location permissions on app startup
  static Future<bool> requestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
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
      _isTracking = true;
      developer.log('Starting location tracking');

      // Get tracking interval from preferences (default 30 seconds)
      final interval = Preferences.instance.getInt(Preferences.interval) ?? 30;
      
      // Start periodic location updates
      _locationTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
        await _getCurrentLocationAndSend();
      });

      // Also send initial location immediately
      await _getCurrentLocationAndSend();

    } catch (error) {
      developer.log('Error starting tracking: $error');
      _isTracking = false;
      rethrow;
    }
  }

  /// Stop location tracking
  static Future<void> stopTracking() async {
    if (!_isTracking) return;

    developer.log('Stopping location tracking');
    _isTracking = false;
    
    _locationTimer?.cancel();
    _locationTimer = null;
    
    await _positionStream?.cancel();
    _positionStream = null;
  }

  /// Send a single location update (for SOS or manual requests)
  static Future<void> sendSingleUpdate() async {
    await _getCurrentLocationAndSend();
  }

  /// Force a fresh GPS reading and send to server (clears any cached/test data)
  static Future<void> sendFreshGPSUpdate() async {
    try {
      developer.log('Forcing fresh GPS reading to clear any test data...');
      
      // Get a fresh GPS position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
        forceAndroidLocationManager: true, // Force native GPS
      );

      developer.log('Fresh GPS position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
      
      // Send immediately to server
      await _sendLocationToServer(position);
      
      developer.log('Fresh GPS update sent to server successfully');
    } catch (error) {
      developer.log('Error sending fresh GPS update: $error');
      rethrow;
    }
  }

  /// Get current location and send to server
  static Future<void> _getCurrentLocationAndSend() async {
    try {
      developer.log('Getting current GPS position...');
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

      // Prepare location data for Traccar
      final locationData = {
        'id': deviceId,
        'lat': position.latitude,
        'lon': position.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'altitude': position.altitude,
        'speed': position.speed,
        'bearing': position.heading,
        'accuracy': position.accuracy,
      };

      // Send to Traccar server using OsmAnd protocol (simple HTTP GET)
      final url = Uri.parse('$serverUrl/?${_buildQueryString(locationData)}');
      
      developer.log('Sending location to: $url');
      developer.log('Location data: ${position.latitude}, ${position.longitude}');
      
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

      // Test server connectivity by making a request to the tracking endpoint without location data
      // This tests the actual endpoint but avoids sending coordinates that could interfere with tracking
      final testData = {
        'id': deviceId,
        'test': 'connection', // Mark as connection test only
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
      // Traccar returns 200 for valid requests, even without location data
      final connected = response.statusCode == 200;
      
      // Extract server host for display
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

      // Test server connectivity by making a request to the tracking endpoint without location data
      // This tests the actual endpoint but avoids sending coordinates that could interfere with tracking
      final testData = {
        'id': deviceId,
        'test': 'connection', // Mark as connection test only
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
      // Traccar returns 200 for valid requests, even without location data
      return response.statusCode == 200;
    } catch (error) {
      developer.log('Server connection test failed: $error');
      return false;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  const TimeoutException(this.message, this.timeout);
  
  @override
  String toString() => 'TimeoutException: $message';
}