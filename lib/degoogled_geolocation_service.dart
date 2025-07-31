import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:traccar_client/location_cache.dart';
import 'package:traccar_client/preferences.dart';


class DegoogledGeolocationService {
  static bool _isInitialized = false;
  static bool _hasGooglePlayServices = true;

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
      
      // Handle license validation errors
      if (error.toString().contains('LICENSE VALIDATION ERROR') || 
          error.toString().contains('license key')) {
        developer.log('License validation error - continuing with free version');
        // For free version, try to continue with basic functionality
        try {
          await _initializeWithBasicConfig();
          _isInitialized = true;
          return;
        } catch (e) {
          developer.log('Failed to initialize with basic config', error: e);
        }
      }
      
      // Check if the error is related to Google Play Services
      if (error.toString().contains('Google Play Services') || 
          error.toString().contains('HMS are installed')) {
        _hasGooglePlayServices = false;
        developer.log('Google Play Services not available, using native location services');
        
        // Try to initialize with minimal configuration for native services
        try {
          await _initializeNativeLocationServices();
          _isInitialized = true;
        } catch (e) {
          developer.log('Failed to initialize native location services', error: e);
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  static Future<void> _initializeWithBasicConfig() async {
    // Create a very basic configuration for free version
    final config = bg.Config(
      isMoving: true,
      enableHeadless: false, // Disable headless for free version
      stopOnTerminate: false,
      startOnBoot: true,
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_MEDIUM,
      autoSync: false, // Use manual sync like original
      url: Preferences.instance.getString(Preferences.url),
      params: {
        'device_id': Preferences.instance.getString(Preferences.id),
      },
      distanceFilter: (Preferences.instance.getInt(Preferences.distance) ?? 75).toDouble(),
      locationUpdateInterval: (Preferences.instance.getInt(Preferences.interval) ?? 300) * 1000,
      maxRecordsToPersist: 10, // Limit for free version
      logLevel: bg.Config.LOG_LEVEL_ERROR, // Reduce logging
      locationTemplate: _locationTemplate(),
      disableElasticity: true,
      notification: bg.Notification(
        smallIcon: 'drawable/ic_stat_notify',
        priority: bg.Config.NOTIFICATION_PRIORITY_LOW,
      ),
      showsBackgroundLocationIndicator: false,
      debug: false, // Disable debug for free version
    );

    await bg.BackgroundGeolocation.ready(config);
    
    bg.BackgroundGeolocation.onEnabledChange(onEnabledChange);
    bg.BackgroundGeolocation.onMotionChange(onMotionChange);
    bg.BackgroundGeolocation.onLocation(onLocation, (bg.LocationError error) {
      developer.log('Location error', error: error);
    });
  }

  static Future<void> _initializeNativeLocationServices() async {
    // Create a minimal configuration that doesn't rely on Google Play Services
    final config = bg.Config(
      isMoving: true,
      enableHeadless: true,
      stopOnTerminate: false,
      startOnBoot: true,
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_MEDIUM,
      autoSync: false, // Use manual sync like original
      url: Preferences.instance.getString(Preferences.url),
      params: {
        'device_id': Preferences.instance.getString(Preferences.id),
      },
      distanceFilter: (Preferences.instance.getInt(Preferences.distance) ?? 75).toDouble(),
      locationUpdateInterval: (Preferences.instance.getInt(Preferences.interval) ?? 300) * 1000,
      maxRecordsToPersist: Preferences.instance.getBool(Preferences.buffer) != false ? -1 : 1,
      logLevel: bg.Config.LOG_LEVEL_VERBOSE,
      logMaxDays: 1,
      locationTemplate: _locationTemplate(),
      disableElasticity: true,
      disableStopDetection: Preferences.instance.getBool(Preferences.stopDetection) == false,
      notification: bg.Notification(
        smallIcon: 'drawable/ic_stat_notify',
        priority: bg.Config.NOTIFICATION_PRIORITY_LOW,
      ),
      showsBackgroundLocationIndicator: false,
    );

    await bg.BackgroundGeolocation.ready(config);
    
    if (Platform.isAndroid) {
      await bg.BackgroundGeolocation.registerHeadlessTask(headlessTask);
    }
    bg.BackgroundGeolocation.onEnabledChange(onEnabledChange);
    bg.BackgroundGeolocation.onMotionChange(onMotionChange);
    bg.BackgroundGeolocation.onHeartbeat(onHeartbeat);
    bg.BackgroundGeolocation.onLocation(onLocation, (bg.LocationError error) {
      developer.log('Location error', error: error);
    });
  }

  static String _locationTemplate() {
    return '''{
      "timestamp": "<%= timestamp %>",
      "coords": {
        "latitude": <%= latitude %>,
        "longitude": <%= longitude %>,
        "accuracy": <%= accuracy %>,
        "speed": <%= speed %>,
        "heading": <%= heading %>,
        "altitude": <%= altitude %>
      },
      "is_moving": <%= is_moving %>,
      "odometer": <%= odometer %>,
      "event": "<%= event %>",
      "battery": {
        "level": <%= battery.level %>,
        "is_charging": <%= battery.is_charging %>
      },
      "activity": {
        "type": "<%= activity.type %>"
      },
      "extras": {},
      "_": "&id=${Preferences.instance.getString(Preferences.id)}&lat=<%= latitude %>&lon=<%= longitude %>&timestamp=<%= timestamp %>&"
    }'''.split('\n').map((line) => line.trimLeft()).join();
  }

  static Future<void> startTracking() async {
    try {
      developer.log('Starting background geolocation tracking...');
      await bg.BackgroundGeolocation.start();
      
      // Verify the service actually started and get current state
      final state = await bg.BackgroundGeolocation.state;
      developer.log('Tracking started successfully - enabled: ${state.enabled}, tracking: ${state.trackingMode}');
      developer.log('Current location settings - URL: ${state.url}, autoSync: ${state.autoSync}');
      
      // Check location permissions
      final providerState = await bg.BackgroundGeolocation.providerState;
      developer.log('Location permissions - status: ${providerState.status}, GPS enabled: ${providerState.gps}, network enabled: ${providerState.network}');
      
      // Request an immediate location to test the system
      developer.log('Requesting immediate location after start...');
      try {
        await bg.BackgroundGeolocation.getCurrentPosition(samples: 1, persist: true, extras: {'startup_test': true});
        developer.log('Immediate location request completed');
      } catch (locError) {
        developer.log('Immediate location request failed', error: locError);
      }
      
    } catch (error) {
      developer.log('Error starting tracking', error: error);
      
      // Handle license validation errors
      if (error.toString().contains('LICENSE VALIDATION ERROR') || 
          error.toString().contains('license key')) {
        developer.log('License validation error - attempting to start with free version');
        
        try {
          // Try to reconfigure with basic settings and start
          await _initializeWithBasicConfig();
          await bg.BackgroundGeolocation.start();
          developer.log('Tracking started with free version configuration');
          return;
        } catch (e) {
          developer.log('Failed to start tracking with free version', error: e);
        }
      }
      
      if (error.toString().contains('Google Play Services') || 
          error.toString().contains('HMS are installed')) {
        developer.log('Google Play Services warning ignored, attempting to start with native services');
        
        // Try to start anyway - the plugin might still work
        try {
          await Future.delayed(const Duration(milliseconds: 1000));
          final state = await bg.BackgroundGeolocation.state;
          if (!state.enabled) {
            // Force a configuration update to try again
            await bg.BackgroundGeolocation.ready(Preferences.geolocationConfig());
            await bg.BackgroundGeolocation.start();
          }
          developer.log('Tracking started with native location services');
        } catch (e) {
          developer.log('Failed to start tracking with native services', error: e);
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  static Future<void> stopTracking() async {
    await bg.BackgroundGeolocation.stop();
  }

  static Future<void> getCurrentPosition() async {
    try {
      developer.log('Requesting current position...');
      
      // Check permissions first
      final providerState = await bg.BackgroundGeolocation.providerState;
      developer.log('Provider state for getCurrentPosition: status=${providerState.status}, GPS=${providerState.gps}, network=${providerState.network}');
      
      if (providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED ||
          providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED) {
        throw Exception('Location permissions not granted. Please grant location permissions first.');
      }
      
      if (!providerState.gps && !providerState.network) {
        throw Exception('Location services disabled. Please enable GPS/Location services in device settings.');
      }
      
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 1, 
        persist: true, 
        timeout: 30,
        maximumAge: 5000,
        desiredAccuracy: 10,
        extras: {'manual': true}
      );
      developer.log('Current position obtained: lat=${location.coords.latitude}, lon=${location.coords.longitude}');
    } catch (error) {
      if (error.toString().contains('Google Play Services') || 
          error.toString().contains('HMS are installed')) {
        developer.log('Google Play Services warning ignored for location request');
        // The location might still have been obtained despite the warning
      } else {
        developer.log('Failed to get current position', error: error);
        rethrow;
      }
    }
  }

  static Future<void> testServerConnection() async {
    try {
      developer.log('Testing server connection...');
      final state = await bg.BackgroundGeolocation.state;
      developer.log('Server URL: ${state.url}');
      developer.log('Device ID: ${Preferences.instance.getString(Preferences.id)}');
      
      // Force a sync to test server connection
      await bg.BackgroundGeolocation.sync();
      developer.log('Server connection test completed');
    } catch (error) {
      developer.log('Server connection test failed', error: error);
      rethrow;
    }
  }

  static bool get hasGooglePlayServices => _hasGooglePlayServices;

  static Future<void> requestLocationPermissions() async {
    try {
      developer.log('🔐 Requesting location permissions...');
      
      // Request location permission
      final status = await bg.BackgroundGeolocation.requestPermission();
      developer.log('Permission request result: $status');
      
      // Check the result
      final providerState = await bg.BackgroundGeolocation.providerState;
      developer.log('After permission request - GPS: ${providerState.gps}, Network: ${providerState.network}, Status: ${providerState.status}');
      
    } catch (error) {
      developer.log('❌ Failed to request permissions', error: error);
      rethrow;
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      developer.log('Background geolocation not initialized, initializing now...');
      await init();
    }
    
    // Verify the service is ready
    try {
      final state = await bg.BackgroundGeolocation.state;
      developer.log('Background geolocation state after ensure initialized: enabled=${state.enabled}, url=${state.url}');
    } catch (error) {
      developer.log('Failed to get background geolocation state', error: error);
      throw Exception('Background geolocation service not properly initialized');
    }
  }

  // Original callback methods from GeolocationService
  static Future<void> onEnabledChange(bool enabled) async {
    developer.log('🔄 ENABLED CHANGE CALLBACK: enabled=$enabled');
    if (Preferences.instance.getBool(Preferences.wakelock) ?? false) {
      if (!enabled) {
        // Wakelock functionality removed for degoogled compatibility
      }
    }
  }

  static Future<void> onMotionChange(bg.Location location) async {
    developer.log('🚶 MOTION CHANGE CALLBACK: isMoving=${location.isMoving}, lat=${location.coords.latitude}, lon=${location.coords.longitude}');
    if (Preferences.instance.getBool(Preferences.wakelock) ?? false) {
      if (location.isMoving) {
        // Wakelock functionality removed for degoogled compatibility
      } else {
        // Wakelock functionality removed for degoogled compatibility
      }
    }
  }

  static Future<void> onHeartbeat(bg.HeartbeatEvent event) async {
    developer.log('💓 HEARTBEAT CALLBACK: Requesting current position');
    try {
      await bg.BackgroundGeolocation.getCurrentPosition(samples: 1, persist: true, extras: {'heartbeat': true});
      developer.log('Heartbeat position request completed');
    } catch (error) {
      developer.log('Heartbeat position request failed', error: error);
    }
  }

  static Future<void> onLocation(bg.Location location) async {
    developer.log('🎯 LOCATION CALLBACK TRIGGERED! lat=${location.coords.latitude}, lon=${location.coords.longitude}, timestamp=${location.timestamp}');
    developer.log('Location details - accuracy: ${location.coords.accuracy}, speed: ${location.coords.speed}, isMoving: ${location.isMoving}');
    developer.log('Location extras: ${location.extras}');
    
    if (_shouldDelete(location)) {
      try {
        await bg.BackgroundGeolocation.destroyLocation(location.uuid);
        developer.log('Location deleted due to filtering');
      } catch(error) {
        developer.log('Failed to delete location', error: error);
      }
    } else {
      LocationCache.set(location);
      developer.log('Location cached, attempting to sync to server');
      try {
        await bg.BackgroundGeolocation.sync();
        developer.log('✅ Location sync completed successfully');
      } catch (error) {
        developer.log('❌ Failed to send location to server', error: error);
        // Try to get more details about the sync failure
        final state = await bg.BackgroundGeolocation.state;
        developer.log('Current config - URL: ${state.url}, enabled: ${state.enabled}');
      }
    }
  }

  static bool _shouldDelete(bg.Location location) {
    developer.log('🔍 Checking if location should be deleted - isMoving: ${location.isMoving}, extras: ${location.extras}');
    
    if (!location.isMoving) {
      developer.log('Location kept - not moving');
      return false;
    }
    if (location.extras?.isNotEmpty == true) {
      developer.log('Location kept - has extras');
      return false;
    }

    final lastLocation = LocationCache.get();
    if (lastLocation == null) {
      developer.log('Location kept - no previous location');
      return false;
    }

    final isHighestAccuracy = Preferences.instance.getString(Preferences.accuracy) == 'highest';
    final duration = DateTime.parse(location.timestamp).difference(DateTime.parse(lastLocation.timestamp)).inSeconds;

    if (!isHighestAccuracy) {
      final fastestInterval = Preferences.instance.getInt(Preferences.fastestInterval);
      if (fastestInterval != null && duration < fastestInterval) return true;
    }

    final distance = _distance(lastLocation, location);

    final distanceFilter = Preferences.instance.getInt(Preferences.distance) ?? 0;
    if (distanceFilter > 0 && distance >= distanceFilter) return false;

    if (distanceFilter == 0 || isHighestAccuracy) {
      final intervalFilter = Preferences.instance.getInt(Preferences.interval) ?? 0;
      if (intervalFilter > 0 && duration >= intervalFilter) {
        developer.log('Location kept - interval filter passed');
        return false;
      }
    }

    if (isHighestAccuracy && lastLocation.heading >= 0 && location.coords.heading > 0) {
      final angle = (location.coords.heading - lastLocation.heading).abs();
      final angleFilter = Preferences.instance.getInt(Preferences.angle) ?? 0;
      if (angleFilter > 0 && angle >= angleFilter) {
        developer.log('Location kept - angle filter passed');
        return false;
      }
    }

    developer.log('❌ Location will be DELETED due to filtering');
    return true;
  }

  static double _distance(Location from, bg.Location to) {
    const earthRadius = 6371008.8; // meters
    final dLat = _degToRad(to.coords.latitude - from.latitude);
    final dLon = _degToRad(to.coords.longitude - from.longitude);
    final sinLat = sin(dLat / 2);
    final sinLon = sin(dLon / 2);
    final a = sinLat * sinLat + cos(_degToRad(from.latitude)) * cos(_degToRad(to.coords.latitude)) * sinLon * sinLon;
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double degree) => degree * pi / 180.0;
}

@pragma('vm:entry-point')
void headlessTask(bg.HeadlessEvent headlessEvent) async {
  await Preferences.init();
  switch (headlessEvent.name) {
    case bg.Event.ENABLEDCHANGE:
      await DegoogledGeolocationService.onEnabledChange(headlessEvent.event);
      break;
    case bg.Event.MOTIONCHANGE:
      await DegoogledGeolocationService.onMotionChange(headlessEvent.event);
      break;
    case bg.Event.HEARTBEAT:
      await DegoogledGeolocationService.onHeartbeat(headlessEvent.event);
      break;
    case bg.Event.LOCATION:
      await DegoogledGeolocationService.onLocation(headlessEvent.event);
      break;
  }
}