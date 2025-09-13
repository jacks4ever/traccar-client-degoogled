import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static final Preferences _instance = Preferences._internal();
  factory Preferences() => _instance;
  Preferences._internal();

  Future<SharedPreferences> get prefs async => SharedPreferences.getInstance();

  // String preferences
  Future<void> setString(String key, String value) async {
    final prefs = await this.prefs;
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await this.prefs;
    return prefs.getString(key);
  }

  // Int preferences
  Future<void> setInt(String key, int value) async {
    final prefs = await this.prefs;
    await prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await this.prefs;
    return prefs.getInt(key);
  }

  // Bool preferences
  Future<void> setBool(String key, bool value) async {
    final prefs = await this.prefs;
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await this.prefs;
    return prefs.getBool(key);
  }

  // Migration methods
  static String? _formatUrl(String? url) {
    if (url == null) return null;
    final uri = Uri.parse(url);
    if ((uri.path.isEmpty || uri.path == '') && !url.endsWith('/')) return '$url/';
    return url;
  }

  Future<void> migrate() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Migrate old preferences to new keys
    final oldId = prefs.getString('device_id_preference');
    if (oldId != null) {
      await prefs.setString(Preferences.id, oldId);
      await prefs.remove('device_id_preference');
    }
    
    final oldUrl = prefs.getString('server_url_preference');
    if (oldUrl != null) {
      await prefs.setString(Preferences.url, _formatUrl(oldUrl)!);
      await prefs.remove('server_url_preference');
    }
    
    final oldAccuracy = prefs.getString('accuracy_preference');
    if (oldAccuracy != null) {
      await prefs.setString(Preferences.accuracy, oldAccuracy);
      await prefs.remove('accuracy_preference');
    }
    
    final oldIntervalString = prefs.getString('frequency_preference');
    if (oldIntervalString != null) {
      final oldInterval = int.tryParse(oldIntervalString);
      if (oldInterval != null) {
        await prefs.setInt(Preferences.interval, oldInterval);
      }
      await prefs.remove('frequency_preference');
    }
    
    final oldDistanceString = prefs.getString('distance_preference');
    if (oldDistanceString != null) {
      final oldDistance = int.tryParse(oldDistanceString);
      if (oldDistance != null) {
        await prefs.setInt(Preferences.distance, oldDistance > 0 ? oldDistance : 75);
      }
      await prefs.remove('distance_preference');
    }
    
    final oldBuffer = prefs.getBool('buffer_preference');
    if (oldBuffer != null) {
      await prefs.setBool(Preferences.buffer, oldBuffer);
      await prefs.remove('buffer_preference');
    }
  }

  // Preference keys
  static const String id = 'device_id';
  static const String url = 'server_url';
  static const String accuracy = 'location_accuracy';
  static const String interval = 'update_interval';
  static const String distance = 'distance_filter';
  static const String buffer = 'buffer_preference';

  // Init method
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // You can add any initialization logic here if needed
  }
}
