import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:traccar_client/main.dart';
import 'package:traccar_client/password_service.dart';
import 'package:traccar_client/preferences.dart';
import 'package:traccar_client/simple_location_service.dart';

import 'l10n/app_localizations.dart';
import 'simple_status_screen.dart';
import 'simple_settings_screen.dart';

class SimpleMainScreen extends StatefulWidget {
  const SimpleMainScreen({super.key});

  @override
  State<SimpleMainScreen> createState() => _SimpleMainScreenState();
}

class _SimpleMainScreenState extends State<SimpleMainScreen> {
  bool trackingEnabled = false;
  Map<String, dynamic>? locationStatus;
  Timer? _statusTimer;
  bool? serverConnectionStatus;
  String? connectionStatusMessage;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _initState() async {
    // Check initial tracking state
    trackingEnabled = SimpleLocationService.isTracking;
    
    // Test server connection on startup
    _testServerConnection();
    
    // Update location status periodically - but only get cached status, not fresh GPS
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted) {
        final status = await SimpleLocationService.getCachedStatus();
        setState(() {
          locationStatus = status;
        });
      }
    });
    
    // Get initial cached status (no GPS request)
    final status = await SimpleLocationService.getCachedStatus();
    if (mounted) {
      setState(() {
        locationStatus = status;
      });
    }
  }

  void _testServerConnection() async {
    if (mounted) {
      setState(() {
        serverConnectionStatus = null; // Show testing state
        connectionStatusMessage = 'Testing connection...';
      });
    }
    
    try {
      final result = await SimpleLocationService.testServerConnectionDetailed();
      if (mounted) {
        setState(() {
          serverConnectionStatus = result['connected'] as bool;
          connectionStatusMessage = result['message'] as String;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          serverConnectionStatus = false;
          connectionStatusMessage = 'Connection error: ${error.toString()}';
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh state when returning from other screens
    _refreshState();
  }

  void _refreshState() async {
    final status = await SimpleLocationService.getCachedStatus();
    if (mounted) {
      setState(() {
        trackingEnabled = SimpleLocationService.isTracking;
        locationStatus = status;
      });
    }
  }

  void _sendFreshGPS() async {
    try {
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Getting fresh GPS location...'),
          duration: Duration(seconds: 2),
        ),
      );

      await SimpleLocationService.sendFreshGPSUpdate();
      
      if (mounted) {
        messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Fresh GPS location sent to server!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Refresh the location status
        _refreshState();
      }
    } catch (error) {
      if (mounted) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Failed to get GPS location: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
              subtitle: Text(trackingEnabled 
                ? 'Sending location data to server' 
                : 'Location tracking stopped'),
              value: trackingEnabled,
              onChanged: (bool value) async {
                if (await PasswordService.authenticate(context) && mounted) {
                  try {
                    if (value) {
                      await SimpleLocationService.startTracking();
                      if (mounted) {
                        setState(() {
                          trackingEnabled = true;
                        });
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('Location tracking started'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      await SimpleLocationService.stopTracking();
                      if (mounted) {
                        setState(() {
                          trackingEnabled = false;
                        });
                        messengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('Location tracking stopped'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  } catch (error) {
                    developer.log('Error toggling tracking: $error');
                    if (mounted) {
                      messengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text('Error: ${error.toString()}'),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                }
              },
            ),
            if (locationStatus != null) ...[
              const Divider(),
              _buildLocationStatus(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStatus() {
    if (locationStatus == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Location',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (locationStatus!.containsKey('latitude') && locationStatus!.containsKey('longitude')) ...[
          Text('Latitude: ${locationStatus!['latitude']?.toStringAsFixed(6) ?? 'Unknown'}'),
          Text('Longitude: ${locationStatus!['longitude']?.toStringAsFixed(6) ?? 'Unknown'}'),
          if (locationStatus!.containsKey('accuracy'))
            Text('Accuracy: ${locationStatus!['accuracy']?.toStringAsFixed(1) ?? 'Unknown'}m'),
          if (locationStatus!.containsKey('timestamp'))
            Text('Updated: ${locationStatus!['timestamp'] ?? 'Unknown'}'),
        ],
        if (locationStatus!.containsKey('error'))
          Text(
            'Error: ${locationStatus!['error']}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Widget _buildServerCard() {
    final server = Preferences.instance.getString(Preferences.url);
    final interval = Preferences.instance.getInt(Preferences.interval) ?? 30;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Server Configuration'),
              titleTextStyle: Theme.of(context).textTheme.headlineMedium,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Server URL'),
              subtitle: Text(server ?? 'Not configured'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Update Interval'),
              subtitle: Text('${interval}s'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Connection Status'),
              subtitle: Row(
                children: [
                  Icon(
                    serverConnectionStatus == true 
                        ? Icons.check_circle 
                        : serverConnectionStatus == false 
                            ? Icons.error 
                            : Icons.hourglass_empty,
                    size: 16,
                    color: serverConnectionStatus == true 
                        ? Colors.green 
                        : serverConnectionStatus == false 
                            ? Colors.red 
                            : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connectionStatusMessage ?? 
                          (serverConnectionStatus == true 
                              ? 'Connected' 
                              : serverConnectionStatus == false 
                                  ? 'Connection failed' 
                                  : 'Testing...'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _testServerConnection,
                tooltip: 'Test connection',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendFreshGPS,
                    icon: const Icon(Icons.gps_fixed, size: 18),
                    label: const Text('Send Fresh GPS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SimpleStatusScreen()),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SimpleSettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTrackingCard(),
            const SizedBox(height: 16),
            _buildServerCard(),
            const SizedBox(height: 32),
            Text(
              'Simple Degoogled Traccar Client v9.5.2d\nNo Google Services Required',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
