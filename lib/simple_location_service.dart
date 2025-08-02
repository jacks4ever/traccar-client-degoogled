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

  /// Get current location and send to server
  static Future<void> _getCurrentLocationAndSend() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      return {
        'tracking': _isTracking,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      return {
        'tracking': _isTracking,
        'error': error.toString(),
      };
    }
  }

  /// Test server connection
  static Future<bool> testServerConnection() async {
    try {
      final serverUrl = Preferences.instance.getString(Preferences.url);
      if (serverUrl == null) {
        developer.log('No server URL configured');
        return false;
      }

      // Test with a simple ping to the server
      final url = Uri.parse('$serverUrl/');
      developer.log('Testing connection to: $url');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection test timeout', const Duration(seconds: 10));
        },
      );

      developer.log('Server connection test: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 404; // 404 is also OK for Traccar
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