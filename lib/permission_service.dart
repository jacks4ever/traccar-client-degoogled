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
        // Check again after user potentially enabled location services
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          return false;
        }
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      developer.log('Current location permission: $permission');
      
      // Request location permission if needed
      if (permission == LocationPermission.denied) {
        developer.log('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        developer.log('Permission result: $permission');
      }

      // Handle permanently denied permissions
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          await _showPermissionDeniedDialog(context);
        }
        return false;
      }

      // If still denied after request, return false
      if (permission == LocationPermission.denied) {
        developer.log('Location permission denied by user');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for GPS tracking'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }

      // If we have basic permission, try to get background permission
      if (permission == LocationPermission.whileInUse) {
        developer.log('Requesting background location permission...');
        
        // Request always permission for background tracking
        final backgroundPermission = await Geolocator.requestPermission();
        if (backgroundPermission == LocationPermission.always) {
          permission = backgroundPermission;
          developer.log('Background location permission granted');
        } else {
          developer.log('Background location permission not granted, continuing with while-in-use');
        }
      }

      // Show battery optimization guidance (non-blocking) only if we have location permission
      if (context.mounted && (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
        // Don't await this - let it show in background
        _showBatteryOptimizationDialog(context);
      }

      developer.log('Permission setup completed with permission: $permission');
      return true;
    } catch (error) {
      developer.log('Error requesting permissions: $error');
      return false;
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
  // ignore: unused_element
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
  // ignore: unused_element
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
