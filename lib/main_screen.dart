import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traccar_client/degoogled_geolocation_service.dart';
import 'package:traccar_client/main.dart';
import 'package:traccar_client/native_location_service.dart';
import 'package:traccar_client/password_service.dart';
import 'package:traccar_client/preferences.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'l10n/app_localizations.dart';
import 'status_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool trackingEnabled = false;
  bool? isMoving;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _showPermissionGuidanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permissions Required'),
          content: const Text(
            'This app needs location permissions to track your position.\n\n'
            'Please:\n'
            '1. Tap "Open Settings" below\n'
            '2. Go to Permissions → Location\n'
            '3. Select "Allow all the time"\n'
            '4. Return to the app and try again'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Show instructions to manually open settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please go to Android Settings → Apps → Traccar Client → Permissions → Location → Allow all the time'),
                    duration: Duration(seconds: 8),
                  ),
                );
              },
              child: const Text('Got It'),
            ),
          ],
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh state when returning from other screens
    _refreshState();
  }

  void _initState() async {
    final state = await bg.BackgroundGeolocation.state;
    if (mounted) {
      setState(() {
        trackingEnabled = state.enabled;
        isMoving = state.isMoving;
      });
    }
    bg.BackgroundGeolocation.onEnabledChange((bool enabled) {
      if (mounted) {
        setState(() {
          trackingEnabled = enabled;
        });
      }
    });
    bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
      if (mounted) {
        setState(() {
          isMoving = location.isMoving;
        });
      }
    });
  }

  void _refreshState() async {
    try {
      final state = await bg.BackgroundGeolocation.state;
      if (mounted) {
        setState(() {
          trackingEnabled = state.enabled;
          isMoving = state.isMoving;
        });
      }
    } catch (error) {
      developer.log('Error refreshing state', error: error);
    }
  }

  Future<void> _checkBatteryOptimizations(BuildContext context) async {
    try {
      if (!await bg.DeviceSettings.isIgnoringBatteryOptimizations) {
        final request = await bg.DeviceSettings.showIgnoreBatteryOptimizations();
        if (!request.seen && context.mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              scrollable: true,
              content: Text(AppLocalizations.of(context)!.optimizationMessage),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    bg.DeviceSettings.show(request);
                  },
                  child: Text(AppLocalizations.of(context)!.okButton),
                ),
              ],
            ),
          );
        }
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  Widget _buildTrackingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.trackingTitle),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.idLabel),
              subtitle: Text(Preferences.instance.getString(Preferences.id) ?? ''),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.trackingLabel),
              value: trackingEnabled,
              activeTrackColor: isMoving == false ? Theme.of(context).colorScheme.error :  null,
              onChanged: (bool value) async {
                if (await PasswordService.authenticate(context) && mounted) {
                  try {
                    if (value) {
                      await DegoogledGeolocationService.startTracking();
                      if (mounted) {
                        setState(() {
                          trackingEnabled = true;
                        });
                        _checkBatteryOptimizations(context);
                      }
                    } else {
                      await DegoogledGeolocationService.stopTracking();
                      if (mounted) {
                        setState(() {
                          trackingEnabled = false;
                        });
                      }
                    }
                  } on PlatformException catch (error) {
                    String errorMessage = error.message ?? error.code;
                    
                    // Handle license validation error
                    if (errorMessage.contains('LICENSE VALIDATION ERROR') || errorMessage.contains('license key')) {
                      developer.log('License validation error - using free version functionality');
                      // For free version, try to continue anyway
                      try {
                        if (value) {
                          await DegoogledGeolocationService.startTracking();
                          if (mounted) {
                            setState(() {
                              trackingEnabled = true;
                            });
                            _checkBatteryOptimizations(context);
                          }
                        } else {
                          await DegoogledGeolocationService.stopTracking();
                          if (mounted) {
                            setState(() {
                              trackingEnabled = false;
                            });
                          }
                        }
                        return;
                      } catch (e) {
                        errorMessage = 'Failed to start tracking. Please check your settings and permissions.';
                      }
                    }
                    
                    // Handle connection errors specifically
                    if (errorMessage.contains('unexpected end of stream')) {
                      errorMessage = 'Server connection interrupted. This may be due to server overload or network issues. Please try again in a few moments.';
                    } else if (errorMessage.contains('Connection closed before full header was received')) {
                      errorMessage = 'Server connection closed prematurely. Please check your server configuration and try again.';
                    } else if (errorMessage.contains('SocketException')) {
                      errorMessage = 'Network connection error. Please check your internet connection and server address.';
                    }
                    
                    // Handle Google Play Services error specifically for de-googled devices
                    if (errorMessage.contains('Google Play Services') || errorMessage.contains('HMS are installed')) {
                      // Check if we actually have location permissions before showing the message
                      final providerState = await bg.BackgroundGeolocation.providerState;
                      if (providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED ||
                          providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED) {
                        errorMessage = 'Location permissions are required for tracking. Please grant location permissions in Settings.';
                      } else {
                        // Don't show error message if permissions are granted - Google Play Services warning can be ignored
                        developer.log('Google Play Services not available but permissions are granted - continuing with native location services');
                        if (mounted) {
                          setState(() {
                            trackingEnabled = value;
                          });
                        }
                        return;
                      }
                    }
                    
                    if (mounted) {
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          duration: const Duration(seconds: 5),
                        )
                      );
                    }
                  } catch (error) {
                    developer.log('Unexpected error in tracking toggle', error: error);
                    if (mounted) {
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text('Failed to ${value ? 'start' : 'stop'} tracking: ${error.toString()}'),
                          duration: const Duration(seconds: 5),
                        )
                      );
                    }
                  }
                }
              },
            ),
            const SizedBox(height: 8),
            OverflowBar(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await DegoogledGeolocationService.getCurrentPosition();
                      // Show success message for location request
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text('Location request sent successfully'),
                          duration: Duration(seconds: 2),
                        )
                      );
                    } on PlatformException catch (error) {
                      String errorMessage = error.message ?? error.code;
                      
                      // Handle connection errors specifically
                      if (errorMessage.contains('unexpected end of stream')) {
                        errorMessage = 'Server connection interrupted. This may be due to server overload or network issues. Please try again in a few moments.';
                      } else if (errorMessage.contains('Connection closed before full header was received')) {
                        errorMessage = 'Server connection closed prematurely. Please check your server configuration and try again.';
                      } else if (errorMessage.contains('SocketException')) {
                        errorMessage = 'Network connection error. Please check your internet connection and server address.';
                      }
                      
                      // Handle Google Play Services error specifically for de-googled devices
                      if (errorMessage.contains('Google Play Services') || errorMessage.contains('HMS are installed')) {
                        // Check if we actually have location permissions before showing the message
                        final providerState = await bg.BackgroundGeolocation.providerState;
                        if (providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED ||
                            providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED) {
                          errorMessage = 'Location permissions are required. Please grant location permissions in Settings.';
                        } else {
                          // Don't show error message if permissions are granted - just show success
                          messengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text('Location request completed using native location services'),
                              duration: Duration(seconds: 2),
                            )
                          );
                          return;
                        }
                      }
                      
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          duration: const Duration(seconds: 3),
                        )
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.locationButton),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await DegoogledGeolocationService.testServerConnection();
                      if (mounted) {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('Server connection test completed successfully'),
                            duration: Duration(seconds: 2),
                          )
                        );
                      }
                    } catch (error) {
                      if (mounted) {
                        messengerKey.currentState?.showSnackBar(
                          SnackBar(
                            content: Text('Server connection failed: ${error.toString()}'),
                            duration: const Duration(seconds: 5),
                          )
                        );
                      }
                    }
                  },
                  child: const Text('Test Server'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      developer.log('🔍 MANUAL LOCATION REQUEST - Force triggering location update');
                      
                      // Check permissions and location services first
                      final providerState = await bg.BackgroundGeolocation.providerState;
                      developer.log('Provider state before force location: status=${providerState.status}, GPS=${providerState.gps}, network=${providerState.network}');
                      
                      // Check if permissions are granted
                      if (providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED ||
                          providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED) {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('Location permissions required. Please grant location permissions first using "Request Perms" button.'),
                            duration: Duration(seconds: 5),
                          )
                        );
                        return;
                      }
                      
                      // Check if GPS is enabled
                      if (!providerState.gps && !providerState.network) {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('Location services disabled. Please enable GPS/Location services in device settings.'),
                            duration: Duration(seconds: 5),
                          )
                        );
                        return;
                      }
                      
                      // Ensure background geolocation service is initialized
                      await DegoogledGeolocationService.ensureInitialized();
                      
                      // Check current state
                      final state = await bg.BackgroundGeolocation.state;
                      developer.log('Current state before force location: enabled=${state.enabled}, tracking=${state.trackingMode}');
                      
                      // Ensure background geolocation service is running and GPS is warmed up
                      if (!state.enabled) {
                        developer.log('🔴 Background geolocation service is STOPPED - starting and warming up for Force Location');
                        
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('🔄 Starting background service and warming up GPS...'),
                            duration: Duration(seconds: 3),
                          )
                        );
                        
                        try {
                          // Initialize the service first
                          await DegoogledGeolocationService.ensureInitialized();
                          await Future.delayed(const Duration(milliseconds: 1000));
                          
                          // Start the background service
                          await bg.BackgroundGeolocation.start();
                          await Future.delayed(const Duration(milliseconds: 3000)); // Give it more time to fully start
                          
                          // Verify it started and get updated state
                          final newState = await bg.BackgroundGeolocation.state;
                          if (newState.enabled) {
                            developer.log('✅ Background geolocation service STARTED - now warming up GPS');
                            
                            // GPS warm-up: Try to get a quick location to initialize GPS
                            try {
                              developer.log('🌡️ GPS warm-up: attempting quick location request...');
                              await bg.BackgroundGeolocation.getCurrentPosition(
                                samples: 1,
                                persist: false, // Don't save warm-up location
                                timeout: 10, // Very short timeout for warm-up
                                maximumAge: 300000, // Accept very old locations for warm-up
                                desiredAccuracy: 1000, // Very relaxed accuracy for warm-up
                                extras: {'warmup': true}
                              );
                              developer.log('✅ GPS warm-up successful');
                            } catch (warmupError) {
                              developer.log('⚠️ GPS warm-up failed (this is normal): ${warmupError.toString()}');
                              // This is expected - warm-up often fails but initializes GPS
                            }
                            
                            // Additional delay to let GPS settle
                            await Future.delayed(const Duration(milliseconds: 2000));
                            
                            messengerKey.currentState?.showSnackBar(
                              const SnackBar(
                                content: Text('✅ Background service started and GPS warmed up'),
                                duration: Duration(seconds: 2),
                              )
                            );
                          } else {
                            developer.log('⚠️ Background geolocation service still STOPPED, but attempting Force Location anyway');
                          }
                        } catch (e) {
                          developer.log('❌ Failed to start background geolocation service for Force Location', error: e);
                          // Continue anyway - getCurrentPosition might still work
                        }
                      } else {
                        developer.log('✅ Background geolocation service is already RUNNING - good for Force Location');
                      }
                      
                      // Final check: Ensure service is still running before Force Location
                      final finalState = await bg.BackgroundGeolocation.state;
                      developer.log('Final state check before Force Location: enabled=${finalState.enabled}');
                      
                      if (!finalState.enabled) {
                        developer.log('⚠️ Service stopped again - making one more attempt to start it');
                        try {
                          await bg.BackgroundGeolocation.start();
                          await Future.delayed(const Duration(milliseconds: 1000));
                        } catch (e) {
                          developer.log('❌ Final service start attempt failed: $e');
                        }
                      }
                      
                      // Hybrid Force Location: flutter_background_geolocation + native Android fallback
                      developer.log('🎯 Starting Hybrid Force Location (plugin + native fallback)...');
                      
                      bool locationObtained = false;
                      
                      // Method 1: Try flutter_background_geolocation (simplified single attempt)
                      try {
                        developer.log('📱 Method 1: Trying flutter_background_geolocation...');
                        final pluginLocation = await bg.BackgroundGeolocation.getCurrentPosition(
                          samples: 1,
                          persist: true, 
                          timeout: 30, // Single 30 second timeout
                          maximumAge: 60000, // Accept locations up to 1 minute old
                          desiredAccuracy: 100, // 100 meter accuracy
                          extras: {'manual_force_hybrid': true, 'method': 'plugin', 'timestamp': DateTime.now().millisecondsSinceEpoch}
                        );
                        locationObtained = true;
                        developer.log('✅ Method 1: flutter_background_geolocation succeeded! Location: ${pluginLocation.coords.latitude}, ${pluginLocation.coords.longitude}');
                      } catch (pluginError) {
                        developer.log('❌ Method 1: flutter_background_geolocation failed with error: $pluginError');
                        developer.log('❌ Method 1: Error type: ${pluginError.runtimeType}');
                        developer.log('❌ Method 1: Error string contains 408: ${pluginError.toString().contains('408')}');
                        developer.log('❌ Method 1: Error string contains "Could not fetch last location": ${pluginError.toString().contains('Could not fetch last location')}');
                        developer.log('❌ Method 1: Full error details: ${pluginError.toString()}');
                        
                        // Specific handling for "Could not fetch last location" error
                        if (pluginError.toString().contains('Could not fetch last location')) {
                          developer.log('🎯 DETECTED: "Could not fetch last location" error - this is exactly what native fallback should handle!');
                        }
                        
                        // Method 2: Native Android LocationManager fallback (like original Traccar client)
                        try {
                          developer.log('🔧 Method 2: Starting native Android LocationManager fallback...');
                          developer.log('🔧 Method 2: Plugin failed, now trying native approach like original Traccar client');
                          
                          // First try last known location (instant)
                          final lastKnown = await NativeLocationService.getLastKnownLocation();
                          if (lastKnown != null) {
                            developer.log('✅ Method 2a: Got last known location from native Android');
                            
                            // Convert native location to bg format and send
                            final locationData = {
                              'coords': {
                                'latitude': lastKnown['latitude'],
                                'longitude': lastKnown['longitude'],
                                'accuracy': lastKnown['accuracy'],
                                'altitude': lastKnown['altitude'],
                                'speed': lastKnown['speed'],
                                'heading': lastKnown['bearing'],
                              },
                              'timestamp': lastKnown['timestamp'],
                              'is_moving': false,
                              'event': 'manual_force_native_cached',
                              'extras': {'method': 'native_cached', 'provider': lastKnown['provider']},
                              'battery': {'level': 0.0, 'is_charging': false}, // Dummy battery data
                              'activity': {'type': 'unknown', 'confidence': 0}, // Dummy activity data
                            };
                            
                            // Manually send to server (since we're bypassing the plugin)
                            developer.log('🔧 Method 2a: Attempting to send native cached location to server...');
                            await bg.BackgroundGeolocation.insertLocation(locationData);
                            locationObtained = true;
                            developer.log('✅ Method 2a: Native cached location sent to server successfully');
                          } else {
                            // No cached location, request fresh one
                            developer.log('🔍 Method 2b: No cached location, requesting fresh GPS via native...');
                            final freshLocation = await NativeLocationService.requestSingleLocation(
                              timeoutSeconds: 45,
                              accuracyMeters: 200,
                            );
                            
                            if (freshLocation != null) {
                              developer.log('✅ Method 2b: Got fresh location from native Android GPS');
                              
                              // Convert and send to server
                              final locationData = {
                                'coords': {
                                  'latitude': freshLocation['latitude'],
                                  'longitude': freshLocation['longitude'],
                                  'accuracy': freshLocation['accuracy'],
                                  'altitude': freshLocation['altitude'],
                                  'speed': freshLocation['speed'],
                                  'heading': freshLocation['bearing'],
                                },
                                'timestamp': freshLocation['timestamp'],
                                'is_moving': false,
                                'event': 'manual_force_native_fresh',
                                'extras': {'method': 'native_fresh', 'provider': freshLocation['provider']},
                                'battery': {'level': 0.0, 'is_charging': false}, // Dummy battery data
                                'activity': {'type': 'unknown', 'confidence': 0}, // Dummy activity data
                              };
                              
                              developer.log('🔧 Method 2b: Attempting to send native fresh location to server...');
                              await bg.BackgroundGeolocation.insertLocation(locationData);
                              locationObtained = true;
                              developer.log('✅ Method 2b: Native fresh location sent to server successfully');
                            } else {
                              developer.log('❌ Method 2b: Native fresh location request failed');
                            }
                          }
                        } catch (nativeError) {
                          developer.log('❌ Method 2: Native Android fallback failed: $nativeError');
                          developer.log('❌ Method 2: Native error type: ${nativeError.runtimeType}');
                          developer.log('❌ Method 2: Native error details: ${nativeError.toString()}');
                        }
                      }
                      
                      // Show success/failure message
                      if (locationObtained) {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('✅ Force Location successful! Location sent to server.'),
                            duration: Duration(seconds: 3),
                          )
                        );
                      } else {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('❌ Force Location failed: Both plugin and native methods failed.\n\nTry:\n• Moving outdoors for better GPS signal\n• Ensuring location services are enabled\n• Checking location permissions\n• Waiting for GPS to initialize (can take 2-3 minutes)'),
                            duration: Duration(seconds: 8),
                          )
                        );
                      }
                    } catch (error) {
                      developer.log('❌ Force location request failed with exception', error: error);
                      
                      String errorMessage = 'Force location failed: ${error.toString()}';
                      
                      // Decode LocationError codes for better user feedback
                      if (error.toString().contains('LocationError code: 1')) {
                        errorMessage = 'Location Error: Permission denied or location services disabled.\n\nPlease check:\n• Location permissions are granted ("Always" recommended)\n• GPS/Location services are enabled in device settings\n• App has background location access\n\nUse "Check Status" to verify settings.';
                      } else if (error.toString().contains('LocationError code: 2')) {
                        errorMessage = 'Location Error: Network error or location unavailable.\n\nTry:\n• Moving to an area with better GPS signal\n• Enabling both GPS and network location\n• Waiting a moment and trying again';
                      } else if (error.toString().contains('LocationError code: 3')) {
                        errorMessage = 'Location Error: Location request timeout.\n\nThis may happen if:\n• GPS signal is weak\n• Device is indoors\n• Location services are slow to respond\n\nTry moving to an open area and retry.';
                      } else if (error.toString().contains('LocationError code: 408')) {
                        errorMessage = 'Location Error: Plugin timeout (408) - but native fallback should have tried.\n\nIf both methods failed:\n• Move outdoors for better GPS signal\n• Wait 2-3 minutes for GPS to initialize\n• Ensure location services are enabled\n• Restart location services in device settings\n\nNote: First GPS fix after reboot can take several minutes.';
                      } else if (error.toString().contains('Google Play Services') || error.toString().contains('HMS are installed')) {
                        errorMessage = 'Google Play Services warning (can be ignored on de-googled devices).\n\nNative fallback should still work. If location fails:\n• Check that GPS is enabled\n• Verify location permissions\n• Try moving to better GPS signal area';
                      }
                      
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          duration: const Duration(seconds: 10),
                        )
                      );
                    }
                  },
                  child: const Text('Force Location'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      developer.log('🔍 CHECKING PERMISSIONS AND LOCATION SERVICES');
                      
                      // Check provider state (permissions and GPS status)
                      final providerState = await bg.BackgroundGeolocation.providerState;
                      developer.log('Provider state: ${providerState.status}');
                      developer.log('GPS enabled: ${providerState.gps}');
                      developer.log('Network enabled: ${providerState.network}');
                      
                      // Check background geolocation state
                      final state = await bg.BackgroundGeolocation.state;
                      developer.log('BG Geolocation enabled: ${state.enabled}');
                      developer.log('Tracking mode: ${state.trackingMode}');
                      developer.log('URL configured: ${state.url}');
                      
                      // Create status message
                      String statusMessage = 'Permission & Service Status:\n';
                      statusMessage += '• GPS: ${providerState.gps ? "✅ Enabled" : "❌ Disabled"}\n';
                      statusMessage += '• Network: ${providerState.network ? "✅ Enabled" : "❌ Disabled"}\n';
                      statusMessage += '• BG Service: ${state.enabled ? "✅ Running" : "❌ Stopped"}\n';
                      
                      // Decode permission status
                      switch (providerState.status) {
                        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS:
                          statusMessage += '• Permissions: ✅ Always allowed';
                          break;
                        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE:
                          statusMessage += '• Permissions: ⚠️ Only when in use';
                          break;
                        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED:
                          statusMessage += '• Permissions: ❌ Denied';
                          break;
                        case bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED:
                          statusMessage += '• Permissions: ❓ Not determined';
                          break;
                        default:
                          statusMessage += '• Permissions: Unknown (${providerState.status})';
                      }
                      
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text(statusMessage),
                          duration: const Duration(seconds: 10),
                        )
                      );
                      
                    } catch (error) {
                      developer.log('❌ Failed to check permissions', error: error);
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text('Failed to check status: ${error.toString()}'),
                          duration: const Duration(seconds: 5),
                        )
                      );
                    }
                  },
                  child: const Text('Check Status'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      developer.log('🔐 Manual permission request triggered');
                      await DegoogledGeolocationService.requestLocationPermissions();
                      
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text('Permission request completed - check status'),
                          duration: Duration(seconds: 3),
                        )
                      );
                    } catch (error) {
                      developer.log('❌ Permission request failed', error: error);
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text('Permission request failed: ${error.toString()}'),
                          duration: const Duration(seconds: 5),
                        )
                      );
                    }
                  },
                  child: const Text('Request Perms'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      final state = await bg.BackgroundGeolocation.state;
                      
                      if (state.enabled) {
                        // Stop the service
                        developer.log('🔴 Manually stopping background geolocation service');
                        await bg.BackgroundGeolocation.stop();
                        
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('🔴 Background location service STOPPED'),
                            duration: Duration(seconds: 3),
                          )
                        );
                      } else {
                        // Start the service
                        developer.log('🟢 Manually starting background geolocation service');
                        await DegoogledGeolocationService.ensureInitialized();
                        await bg.BackgroundGeolocation.start();
                        
                        // Verify it started
                        final newState = await bg.BackgroundGeolocation.state;
                        if (newState.enabled) {
                          messengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text('🟢 Background location service STARTED'),
                              duration: Duration(seconds: 3),
                            )
                          );
                        } else {
                          messengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Failed to start background location service'),
                              duration: Duration(seconds: 3),
                            )
                          );
                        }
                      }
                    } catch (error) {
                      developer.log('❌ Failed to toggle background service', error: error);
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text('Service toggle failed: ${error.toString()}'),
                          duration: const Duration(seconds: 5),
                        )
                      );
                    }
                  },
                  child: const Text('Start/Stop Service'),
                ),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      developer.log('🧪 Testing native Android LocationManager directly...');
                      
                      // Test native location service
                      final hasPermission = await NativeLocationService.hasLocationPermission();
                      final isEnabled = await NativeLocationService.isLocationEnabled();
                      
                      developer.log('Native: Has permission: $hasPermission');
                      developer.log('Native: Location enabled: $isEnabled');
                      
                      if (!hasPermission) {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('❌ Native test: No location permission'),
                            duration: Duration(seconds: 3),
                          )
                        );
                        return;
                      }
                      
                      if (!isEnabled) {
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('❌ Native test: Location services disabled'),
                            duration: Duration(seconds: 3),
                          )
                        );
                        return;
                      }
                      
                      // Try to get last known location
                      developer.log('Native: Trying getLastKnownLocation...');
                      final lastKnown = await NativeLocationService.getLastKnownLocation();
                      
                      if (lastKnown != null) {
                        developer.log('✅ Native: Got last known location: ${lastKnown['latitude']}, ${lastKnown['longitude']} (accuracy: ${lastKnown['accuracy']}m, provider: ${lastKnown['provider']})');
                        messengerKey.currentState?.showSnackBar(
                          SnackBar(
                            content: Text('✅ Native test: Got cached location\nLat: ${lastKnown['latitude']}\nLon: ${lastKnown['longitude']}\nAccuracy: ${lastKnown['accuracy']}m\nProvider: ${lastKnown['provider']}'),
                            duration: const Duration(seconds: 5),
                          )
                        );
                      } else {
                        // Try fresh location request
                        developer.log('Native: No cached location, trying fresh request...');
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('🔍 Native test: No cached location, requesting fresh GPS...'),
                            duration: Duration(seconds: 2),
                          )
                        );
                        
                        final freshLocation = await NativeLocationService.requestSingleLocation(
                          timeoutSeconds: 30,
                          accuracyMeters: 200,
                        );
                        
                        if (freshLocation != null) {
                          developer.log('✅ Native: Got fresh location: ${freshLocation['latitude']}, ${freshLocation['longitude']} (accuracy: ${freshLocation['accuracy']}m, provider: ${freshLocation['provider']})');
                          messengerKey.currentState?.showSnackBar(
                            SnackBar(
                              content: Text('✅ Native test: Got fresh GPS location\nLat: ${freshLocation['latitude']}\nLon: ${freshLocation['longitude']}\nAccuracy: ${freshLocation['accuracy']}m\nProvider: ${freshLocation['provider']}'),
                              duration: const Duration(seconds: 5),
                            )
                          );
                        } else {
                          developer.log('❌ Native: Fresh location request failed');
                          messengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text('❌ Native test: Fresh GPS request failed\nTry moving outdoors or wait for GPS initialization'),
                              duration: Duration(seconds: 5),
                            )
                          );
                        }
                      }
                    } catch (error) {
                      developer.log('❌ Native test failed with exception: $error');
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text('❌ Native test failed: ${error.toString()}'),
                          duration: const Duration(seconds: 5),
                        )
                      );
                    }
                  },
                  child: const Text('Test Native GPS'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusScreen()));
                  },
                  child: Text(AppLocalizations.of(context)!.statusButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.settingsTitle),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.urlLabel),
              subtitle: Text(Preferences.instance.getString(Preferences.url) ?? ''),
            ),
            const SizedBox(height: 8),
            OverflowBar(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    if (await PasswordService.authenticate(context) && mounted) {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    }
                  },
                  child: Text(AppLocalizations.of(context)!.settingsButton),
                ),
              ],
            ),
          ]
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Traccar Client'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTrackingCard(),
            const SizedBox(height: 16),
            _buildSettingsCard(),
          ],
        ),
      ),
    );
  }
}
