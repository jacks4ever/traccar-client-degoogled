import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:http/http.dart' as http;
import 'package:traccar_client/password_service.dart';

import 'preferences.dart';

class PushService {
  static Timer? _pollTimer;
  static const Duration _pollInterval = Duration(minutes: 5);
  
  static Future<void> init() async {
    developer.log('Initializing degoogled push service');
    
    // Start polling for commands instead of using Firebase
    bg.BackgroundGeolocation.onEnabledChange((enabled) async {
      if (enabled) {
        _startCommandPolling();
      } else {
        _stopCommandPolling();
      }
    });
    
    // Check if geolocation is already enabled and start polling
    final enabled = await bg.BackgroundGeolocation.enabled;
    if (enabled) {
      _startCommandPolling();
    }
  }

  static void _startCommandPolling() {
    _stopCommandPolling(); // Stop any existing timer
    
    _pollTimer = Timer.periodic(_pollInterval, (timer) async {
      await _checkForCommands();
    });
    
    developer.log('Started command polling');
  }

  static void _stopCommandPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    developer.log('Stopped command polling');
  }

  static Future<void> _checkForCommands() async {
    final id = Preferences.instance.getString(Preferences.id);
    final url = Preferences.instance.getString(Preferences.url);
    
    if (id == null || url == null) return;
    
    try {
      // Poll the server for pending commands
      final response = await http.get(
        Uri.parse('$url/api/commands/pending?deviceId=$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final commands = jsonDecode(response.body) as List;
        for (final command in commands) {
          await _processCommand(command);
        }
      }
    } catch (error) {
      developer.log('Failed to check for commands', error: error);
    }
  }

  static Future<void> _processCommand(Map<String, dynamic> command) async {
    final commandType = command['type'] as String?;
    
    switch (commandType) {
      case 'positionSingle':
        try {
          await bg.BackgroundGeolocation.getCurrentPosition(
            samples: 1, 
            persist: true, 
            extras: {'remote': true}
          );
        } catch (error) {
          developer.log('Failed to get position', error: error);
        }
        break;
      case 'positionPeriodic':
        await bg.BackgroundGeolocation.start();
        break;
      case 'positionStop':
        await bg.BackgroundGeolocation.stop();
        break;
      case 'factoryReset':
        await PasswordService.setPassword('');
        break;
      default:
        developer.log('Unknown command type: $commandType');
    }
  }

  // Register device with server (replaces Firebase token upload)
  static Future<void> registerDevice() async {
    final id = Preferences.instance.getString(Preferences.id);
    final url = Preferences.instance.getString(Preferences.url);
    
    if (id == null || url == null) return;
    
    try {
      final response = await http.post(
        Uri.parse('$url/api/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'pushType': 'polling', // Indicate we use polling instead of push
          'pollInterval': _pollInterval.inMinutes,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        developer.log('Device registered successfully');
      }
    } catch (error) {
      developer.log('Failed to register device', error: error);
    }
  }
}
