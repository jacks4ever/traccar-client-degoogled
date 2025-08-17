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
