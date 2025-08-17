import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Service to manage foreground service for continuous location tracking
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