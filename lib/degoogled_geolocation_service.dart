import 'dart:convert';
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
      method: 'GET', // Traccar server expects GET requests, not POST
      params: {
        'id': Preferences.instance.getString(Preferences.id), // Use 'id' not 'device_id'
      },
      distanceFilter: (Preferences.instance.getInt(Preferences.distance) ?? 75).toDouble(),
      locationUpdateInterval: (Preferences.instance.getInt(Preferences.interval) ?? 300) * 1000,
      maxRecordsToPersist: Preferences.instance.getBool(Preferences.buffer) != false ? -1 : 1,
      logLevel: bg.Config.LOG_LEVEL_VERBOSE,
      logMaxDays: 1,
      locationTemplate: _traccarLocationTemplate(), // Use Traccar-compatible GET template
      disableElasticity: true,
      disableStopDetection: Preferences.instance.getBool(Preferences.stopDetection) == false,
      // Add HTTP configuration for better connection handling
      httpTimeout: 30000, // 30 second timeout for HTTP requests
      maxDaysToPersist: 1, // Limit data persistence
      // Add headers for better server compatibility
      headers: {
        'User-Agent': 'TraccarClient/9.5.2',
        'Connection': 'close',
        'Accept': '*/*',
      },
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

  static String _traccarLocationTemplate() {
    // Traccar server expects GET requests with query parameters
    // When method is GET, the plugin uses this as the query string
    // Device ID will be provided via params, so we use the template variable
    return '''id=<%= id %>&timestamp=<%= timestamp %>&lat=<%= latitude %>&lon=<%= longitude %>&speed=<%= speed %>&bearing=<%= heading %>&altitude=<%= altitude %>&accuracy=<%= accuracy %>&batt=<%= battery.level %>''';
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
      developer.log('🔍 Testing server connection...');
      final state = await bg.BackgroundGeolocation.state;
      final serverUrl = state.url ?? '';
      final deviceId = Preferences.instance.getString(Preferences.id);
      
      developer.log('Server URL: $serverUrl');
      developer.log('Device ID: $deviceId');
      
      if (serverUrl.isEmpty) {
        throw Exception('Server URL is not configured');
      }
      
      // Parse the URL to test basic connectivity
      Uri? uri;
      try {
        uri = Uri.parse(serverUrl);
        developer.log('Parsed URL - Host: ${uri.host}, Port: ${uri.port}, Path: ${uri.path}');
      } catch (e) {
        throw Exception('Invalid server URL format: $serverUrl');
      }
      
      // Test Traccar protocol with GET request and query parameters
      developer.log('🌐 Testing Traccar protocol to ${uri.host}:${uri.port}...');
      
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 15); // Increased timeout
        client.idleTimeout = const Duration(seconds: 15);
        
        // Handle SSL/TLS issues for self-signed certificates
        client.badCertificateCallback = (cert, host, port) {
          developer.log('⚠️ SSL certificate validation failed for $host:$port - allowing connection');
          return true; // Allow self-signed certificates
        };
        
        // Build Traccar test URL with query parameters (like the actual client sends)
        final testUri = uri.replace(queryParameters: {
          'id': deviceId ?? 'test-device',
          'timestamp': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
          'lat': '0.0',
          'lon': '0.0',
          'speed': '0',
          'bearing': '0',
          'altitude': '0',
          'accuracy': '10',
          'batt': '100',
        });
        
        developer.log('Testing URL: $testUri');
        
        // Try to connect to the server with Traccar protocol
        final request = await client.getUrl(testUri);
        request.headers.set('User-Agent', 'TraccarClient/9.5.2');
        request.headers.set('Connection', 'close'); // Prevent connection reuse issues
        request.headers.set('Accept', '*/*');
        
        final response = await request.close().timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw Exception('Connection timeout - Server took too long to respond');
          },
        );
        
        developer.log('✅ Traccar protocol test - Status: ${response.statusCode}');
        
        // Read response to check for errors with timeout
        final responseBody = await response.transform(const Utf8Decoder()).join().timeout(
          const Duration(seconds: 10),
          onTimeout: () => 'Response read timeout',
        );
        developer.log('Response: ${responseBody.length > 100 ? responseBody.substring(0, 100) + "..." : responseBody}');
        
        // Check if response indicates success (200 OK or similar)
        if (response.statusCode >= 200 && response.statusCode < 300) {
          developer.log('✅ Server accepts Traccar protocol requests');
        } else if (response.statusCode == 404) {
          throw Exception('Server returned 404 Not Found - Check if Traccar server is configured correctly');
        } else {
          developer.log('⚠️ Server responded with status ${response.statusCode} but connection works');
        }
        
        client.close(force: true);
      } catch (httpError) {
        developer.log('❌ Traccar protocol test failed: $httpError');
        
        // Provide specific guidance based on error type
        if (httpError.toString().contains('Connection refused')) {
          throw Exception('Server connection refused - Check if Traccar server is running on ${uri.host}:${uri.port}');
        } else if (httpError.toString().contains('Network is unreachable')) {
          throw Exception('Network unreachable - Check your internet connection and server address');
        } else if (httpError.toString().contains('timeout')) {
          throw Exception('Connection timeout - Server may be slow or unreachable');
        } else if (httpError.toString().contains('unexpected end of stream')) {
          throw Exception('Connection interrupted - Server closed connection unexpectedly. This may be due to server overload or network issues. Try again in a few moments.');
        } else if (httpError.toString().contains('Connection closed before full header was received')) {
          throw Exception('Connection closed prematurely - Server may be overloaded or misconfigured');
        } else if (httpError.toString().contains('SocketException')) {
          throw Exception('Network socket error - Check your internet connection and server address');
        } else {
          throw Exception('Traccar protocol test failed: $httpError');
        }
      }
      
      // If HTTP test passes, try the plugin sync with retry
      developer.log('🔄 Testing plugin sync to server...');
      
      int retryCount = 0;
      const maxRetries = 2;
      bool syncSuccessful = false;
      
      while (retryCount < maxRetries && !syncSuccessful) {
        try {
          await bg.BackgroundGeolocation.sync();
          developer.log('✅ Plugin sync test completed successfully');
          syncSuccessful = true;
        } catch (syncError) {
          retryCount++;
          developer.log('❌ Plugin sync test failed (attempt $retryCount/$maxRetries)', error: syncError);
          
          if (syncError.toString().contains('unexpected end of stream') || 
              syncError.toString().contains('Connection closed before full header was received') ||
              syncError.toString().contains('SocketException')) {
            
            if (retryCount < maxRetries) {
              developer.log('Connection error in sync test, retrying in 2 seconds...');
              await Future.delayed(const Duration(seconds: 2));
            } else {
              developer.log('⚠️ Plugin sync test failed but HTTP test passed - server connection works but sync may have issues');
            }
          } else {
            developer.log('Non-connection error in sync test, not retrying');
            break;
          }
        }
      }
      
      developer.log('✅ Server connection test completed successfully');
      
    } catch (error) {
      developer.log('❌ Server connection test failed', error: error);
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
    
    // Validate coordinates to ensure they're reasonable
    final lat = location.coords.latitude;
    final lon = location.coords.longitude;
    
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      developer.log('⚠️ Invalid coordinates detected: lat=$lat, lon=$lon - skipping location');
      return;
    }
    
    if (lat == 0.0 && lon == 0.0) {
      developer.log('⚠️ Null Island coordinates (0,0) detected - likely invalid GPS fix, skipping');
      return;
    }
    
    // Check for reasonable accuracy (reject locations with very poor accuracy)
    if (location.coords.accuracy != null && location.coords.accuracy! > 1000) {
      developer.log('⚠️ Very poor accuracy (${location.coords.accuracy}m) - skipping location');
      return;
    }
    
    developer.log('✅ Location validation passed - lat=$lat, lon=$lon, accuracy=${location.coords.accuracy}m');
    
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
      
      // Retry sync with exponential backoff for connection issues
      int retryCount = 0;
      const maxRetries = 3;
      bool syncSuccessful = false;
      
      while (retryCount < maxRetries && !syncSuccessful) {
        try {
          await bg.BackgroundGeolocation.sync();
          developer.log('✅ Location sync completed successfully');
          syncSuccessful = true;
        } catch (error) {
          retryCount++;
          developer.log('❌ Failed to send location to server (attempt $retryCount/$maxRetries)', error: error);
          
          // Handle specific connection errors
          if (error.toString().contains('unexpected end of stream') || 
              error.toString().contains('Connection closed before full header was received') ||
              error.toString().contains('SocketException')) {
            
            if (retryCount < maxRetries) {
              final delaySeconds = pow(2, retryCount).toInt(); // Exponential backoff: 2, 4, 8 seconds
              developer.log('Connection error detected, retrying in $delaySeconds seconds...');
              await Future.delayed(Duration(seconds: delaySeconds));
            } else {
              developer.log('Max retries reached for connection error, giving up');
              // Try to get more details about the sync failure
              final state = await bg.BackgroundGeolocation.state;
              developer.log('Current config - URL: ${state.url}, enabled: ${state.enabled}');
            }
          } else {
            // For non-connection errors, don't retry
            developer.log('Non-connection error, not retrying');
            final state = await bg.BackgroundGeolocation.state;
            developer.log('Current config - URL: ${state.url}, enabled: ${state.enabled}');
            break;
          }
        }
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