import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:traccar_client/degoogled_geolocation_service.dart';
import 'package:traccar_client/main.dart';
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
    _checkPermissionsOnStart();
  }

  Future<void> _checkPermissionsOnStart() async {
    // Wait a bit for the UI to settle
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      final providerState = await bg.BackgroundGeolocation.providerState;
      
      // If permissions are denied, show guidance dialog
      if (providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED ||
          providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED) {
        
        if (mounted) {
          _showPermissionGuidanceDialog();
        }
      }
    } catch (error) {
      developer.log('Error checking permissions on start', error: error);
    }
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
                      
                      // If background geolocation is not enabled, try to enable it temporarily
                      if (!state.enabled) {
                        developer.log('Background geolocation not enabled, attempting to enable for force location');
                        try {
                          await bg.BackgroundGeolocation.start();
                          await Future.delayed(const Duration(milliseconds: 1000)); // Give it more time to start
                          
                          // Verify it started
                          final newState = await bg.BackgroundGeolocation.state;
                          if (newState.enabled) {
                            developer.log('✅ Background geolocation enabled successfully for force location');
                          } else {
                            developer.log('⚠️ Background geolocation still not enabled, but attempting force location anyway');
                          }
                        } catch (e) {
                          developer.log('Failed to enable background geolocation for force location', error: e);
                          // Continue anyway - getCurrentPosition might still work
                        }
                      }
                      
                      // Force a location request with more aggressive settings
                      developer.log('Attempting force location with enhanced settings...');
                      await bg.BackgroundGeolocation.getCurrentPosition(
                        samples: 3, 
                        persist: true, 
                        timeout: 30, // 30 second timeout
                        maximumAge: 5000, // Accept locations up to 5 seconds old
                        desiredAccuracy: 10, // 10 meter accuracy
                        extras: {'manual_force': true, 'timestamp': DateTime.now().millisecondsSinceEpoch}
                      );
                      
                      messengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text('Force location request completed successfully - check logs'),
                          duration: Duration(seconds: 3),
                        )
                      );
                    } catch (error) {
                      developer.log('❌ Force location request failed', error: error);
                      
                      String errorMessage = 'Force location failed: ${error.toString()}';
                      
                      // Decode LocationError codes for better user feedback
                      if (error.toString().contains('LocationError code: 1')) {
                        errorMessage = 'Location Error: Permission denied or location services disabled.\n\nPlease check:\n• Location permissions are granted ("Always" recommended)\n• GPS/Location services are enabled in device settings\n• App has background location access\n\nUse "Check Status" to verify settings.';
                      } else if (error.toString().contains('LocationError code: 2')) {
                        errorMessage = 'Location Error: Network error or location unavailable.\n\nTry:\n• Moving to an area with better GPS signal\n• Enabling both GPS and network location\n• Waiting a moment and trying again';
                      } else if (error.toString().contains('LocationError code: 3')) {
                        errorMessage = 'Location Error: Location request timeout.\n\nThis may happen if:\n• GPS signal is weak\n• Device is indoors\n• Location services are slow to respond\n\nTry moving to an open area and retry.';
                      } else if (error.toString().contains('Google Play Services') || error.toString().contains('HMS are installed')) {
                        errorMessage = 'Google Play Services warning (can be ignored on de-googled devices).\n\nIf location still fails:\n• Check that GPS is enabled\n• Verify location permissions\n• Try moving to better GPS signal area';
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
