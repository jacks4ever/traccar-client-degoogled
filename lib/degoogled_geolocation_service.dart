import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:traccar_client/main.dart';
import 'package:traccar_client/preferences.dart';
import 'package:traccar_client/push_service.dart';

class DegoogledGeolocationService {
  static bool _isInitialized = false;

  static Future<void> _initializeIfNeeded() async {
    if (_isInitialized) return;
    
    try {
      await bg.BackgroundGeolocation.ready(Preferences.geolocationConfig());
      if (Platform.isAndroid) {
        await bg.BackgroundGeolocation.registerHeadlessTask(headlessTask);
      }
      bg.BackgroundGeolocation.onEnabledChange(onEnabledChange);
      bg.BackgroundGeolocation.onMotionChange(onMotionChange);
      bg.BackgroundGeolocation.onHeartbeat(onHeartbeat);
      bg.BackgroundGeolocation.onLocation(onLocation, (bg.LocationError error) {
        developer.log('Location error', error: error);
      });
      
      // Set up push service polling when geolocation is enabled/disabled
      bg.BackgroundGeolocation.onEnabledChange((enabled) async {
        if (enabled) {
          PushService.startCommandPolling();
        } else {
          PushService.stopCommandPolling();
        }
      });
      
      _isInitialized = true;
      developer.log('Geolocation service initialized successfully');
    } catch (error) {
      developer.log('Failed to initialize geolocation service', error: error);
      rethrow;
    }
  }

  static Future<void> startTracking() async {
    await _initializeIfNeeded();
    await bg.BackgroundGeolocation.start();
    developer.log('Tracking started');
  }

  static Future<void> stopTracking() async {
    if (_isInitialized) {
      await bg.BackgroundGeolocation.stop();
      developer.log('Tracking stopped');
      
      // Check if auto-enable tracking is enabled
      final autoEnable = Preferences.instance.getBool(Preferences.autoEnableTracking) ?? true;
      if (autoEnable) {
        developer.log('Auto-enable tracking is enabled, scheduling restart...');
        // Schedule restart after a short delay
        Timer(const Duration(seconds: 5), () async {
          developer.log('Auto-restarting tracking...');
          try {
            await startTracking();
            developer.log('Tracking auto-restarted successfully');
            
            // Show notification to user that tracking was auto-restarted
            _showAutoRestartNotification();
          } catch (error) {
            developer.log('Failed to auto-restart tracking: $error');
          }
        });
      }
    }
  }

  static void onEnabledChange(bool enabled) {
    developer.log('Geolocation enabled changed: $enabled');
    
    // If tracking was disabled and auto-enable is on, restart it after a delay
    if (!enabled) {
      final autoEnable = Preferences.instance.getBool(Preferences.autoEnableTracking) ?? true;
      if (autoEnable) {
        developer.log('Auto-enable tracking is enabled, scheduling restart from onEnabledChange...');
        // Schedule restart after a short delay
        Timer(const Duration(seconds: 5), () async {
          developer.log('Auto-restarting tracking from onEnabledChange...');
          try {
            await startTracking();
            developer.log('Tracking auto-restarted successfully from onEnabledChange');
            
            // Show notification to user that tracking was auto-restarted
            _showAutoRestartNotification();
          } catch (error) {
            developer.log('Failed to auto-restart tracking from onEnabledChange: $error');
          }
        });
      }
    }
  }
  
  /// Show notification that tracking was automatically restarted
  static void _showAutoRestartNotification() {
    try {
      // Use the messenger key from main.dart to show a snackbar
      // This will only work if the app is in the foreground
      // For background notifications, a proper notification system would be needed
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

  static void onMotionChange(bg.Location location) {
    developer.log('Motion change: ${location.isMoving}');
  }

  static void onHeartbeat(bg.HeartbeatEvent event) {
    developer.log('Heartbeat: ${event.location}');
  }

  static void onLocation(bg.Location location) {
    developer.log('Location: ${location.coords.latitude}, ${location.coords.longitude}');
  }

  static void headlessTask(bg.HeadlessEvent headlessEvent) async {
    developer.log('Headless event: ${headlessEvent.name}');
    
    switch (headlessEvent.name) {
      case bg.Event.LOCATION:
        bg.Location location = headlessEvent.event;
        developer.log('Headless location: ${location.coords.latitude}, ${location.coords.longitude}');
        break;
      case bg.Event.MOTIONCHANGE:
        bg.Location location = headlessEvent.event;
        developer.log('Headless motion change: ${location.isMoving}');
        break;
      case bg.Event.HEARTBEAT:
        bg.HeartbeatEvent event = headlessEvent.event;
        developer.log('Headless heartbeat: ${event.location}');
        break;
    }
  }
}