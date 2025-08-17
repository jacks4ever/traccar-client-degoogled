import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Native Android LocationManager fallback for Force Location
/// Based on the original Traccar client's simple approach
class NativeLocationService {
  static const MethodChannel _channel = MethodChannel('native_location');
  
  /// Request a single location using native Android LocationManager
  /// This is a fallback when flutter_background_geolocation fails
  static Future<Map<String, dynamic>?> requestSingleLocation({
    int timeoutSeconds = 30,
    double accuracyMeters = 100,
  }) async {
    try {
      developer.log('🔧 Native fallback: Requesting single location via Android LocationManager');
      
      final result = await _channel.invokeMethod('requestSingleLocation', {
        'timeout': timeoutSeconds * 1000, // Convert to milliseconds
        'accuracy': accuracyMeters,
      }).timeout(Duration(seconds: timeoutSeconds + 5));
      
      if (result != null) {
        developer.log('✅ Native fallback: Got location via Android LocationManager');
        return Map<String, dynamic>.from(result);
      } else {
        developer.log('❌ Native fallback: No location from Android LocationManager');
        return null;
      }
    } on PlatformException catch (e) {
      developer.log('❌ Native fallback: Platform exception: ${e.message}');
      return null;
    } on TimeoutException catch (_) {
      developer.log('❌ Native fallback: Timeout after ${timeoutSeconds}s');
      return null;
    } catch (e) {
      developer.log('❌ Native fallback: Unexpected error: $e');
      return null;
    }
  }
  
  /// Get last known location (instant, no GPS request)
  /// Similar to getLastKnownLocation(PASSIVE_PROVIDER) in original client
  static Future<Map<String, dynamic>?> getLastKnownLocation() async {
    try {
      developer.log('📍 Native fallback: Getting last known location');
      
      final result = await _channel.invokeMethod('getLastKnownLocation');
      
      if (result != null) {
        developer.log('✅ Native fallback: Got last known location');
        return Map<String, dynamic>.from(result);
      } else {
        developer.log('ℹ️ Native fallback: No last known location available');
        return null;
      }
    } on PlatformException catch (e) {
      developer.log('❌ Native fallback: Platform exception getting last location: ${e.message}');
      return null;
    } catch (e) {
      developer.log('❌ Native fallback: Error getting last location: $e');
      return null;
    }
  }
  
  /// Check if location services are enabled
  static Future<bool> isLocationEnabled() async {
    try {
      final result = await _channel.invokeMethod('isLocationEnabled');
      return result == true;
    } catch (e) {
      developer.log('❌ Native fallback: Error checking location enabled: $e');
      return false;
    }
  }
  
  /// Check if we have location permissions
  static Future<bool> hasLocationPermission() async {
    try {
      final result = await _channel.invokeMethod('hasLocationPermission');
      return result == true;
    } catch (e) {
      developer.log('❌ Native fallback: Error checking location permission: $e');
      return false;
    }
  }
}
