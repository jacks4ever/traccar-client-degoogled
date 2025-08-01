import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:traccar_client/preferences.dart';

class DegoogledGeolocationService {
  static bool _isInitialized = false;

  static Future<void> init() async {
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
      
      _isInitialized = true;
      developer.log('Geolocation service initialized successfully');
    } catch (error) {
      developer.log('Failed to initialize geolocation service', error: error);
      rethrow;
    }
  }

  static void onEnabledChange(bool enabled) {
    developer.log('Geolocation enabled changed: $enabled');
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