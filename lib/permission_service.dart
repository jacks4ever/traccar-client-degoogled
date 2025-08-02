import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class PermissionService {
  /// Check if all required permissions are granted
  static Future<bool> hasAllPermissions() async {
    final locationPermission = await Geolocator.checkPermission();
    
    return locationPermission == LocationPermission.always ||
           locationPermission == LocationPermission.whileInUse;
  }

  /// Request all necessary permissions with clear explanations
  static Future<bool> requestAllPermissions(BuildContext context) async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          await _showLocationServiceDialog(context);
        }
        return false;
      }

      // Request basic location permission first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          await _showLocationPermissionDialog(context);
        }
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          await _showPermissionDeniedDialog(context);
        }
        return false;
      }

      if (permission == LocationPermission.denied) {
        developer.log('Location permission denied by user');
        return false;
      }

      // Request background location permission if we only have while-in-use
      if (permission == LocationPermission.whileInUse) {
        if (context.mounted) {
          await _showBackgroundLocationDialog(context);
        }
        
        // Try to request always permission
        final alwaysPermission = await Geolocator.requestPermission();
        if (alwaysPermission != LocationPermission.always) {
          developer.log('Background location permission not granted, continuing with while-in-use');
          // Still allow the app to work with while-in-use permission
        }
      }

      // Request other necessary permissions
      await _requestAdditionalPermissions(context);

      developer.log('Permission setup completed');
      return true;
    } catch (error) {
      developer.log('Error requesting permissions: $error');
      return false;
    }
  }

  /// Request additional permissions needed for background operation
  static Future<void> _requestAdditionalPermissions(BuildContext context) async {
    // Show battery optimization dialog (user will need to manually configure)
    if (context.mounted) {
      await _showBatteryOptimizationDialog(context);
    }
  }

  /// Show dialog explaining location services requirement
  static Future<void> _showLocationServiceDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Required'),
          content: const Text(
            'This app requires location services to track your device. '
            'Please enable location services in your device settings and try again.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Show dialog explaining location permission requirement
  static Future<void> _showLocationPermissionDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Traccar Client needs access to your device location to provide GPS tracking functionality. '
            'Your location data will only be sent to your configured Traccar server.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Grant Permission'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Show dialog explaining background location permission
  static Future<void> _showBackgroundLocationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Background Location Access'),
          content: const Text(
            'For continuous tracking, Traccar Client needs permission to access your location '
            'even when the app is not actively in use. This ensures reliable GPS tracking.\n\n'
            'Please select "Allow all the time" in the next permission dialog.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Show dialog for permanently denied permissions
  static Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Location permission has been permanently denied. '
            'Please enable location permission in app settings to use GPS tracking.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Show dialog explaining battery optimization exemption
  static Future<void> _showBatteryOptimizationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Battery Optimization'),
          content: const Text(
            'For reliable background tracking, it\'s recommended to disable battery optimization '
            'for Traccar Client. This ensures the app can continue tracking even when your device '
            'is in power saving mode.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Skip'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Allow'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}