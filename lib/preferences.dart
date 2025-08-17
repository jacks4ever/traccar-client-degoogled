
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static late SharedPreferences instance;

  static const String id = 'id';
  static const String url = 'url';
  static const String accuracy = 'accuracy';
  static const String distance = 'distance';
  static const String interval = 'interval';
  static const String angle = 'angle';
  static const String heartbeat = 'heartbeat';
  static const String fastestInterval = 'fastest_interval';
  static const String buffer = 'buffer';
  static const String wakelock = 'wakelock';
  static const String stopDetection = 'stop_detection';
  static const String autoEnableTracking = 'auto_enable_tracking';

  static const String lastTimestamp = 'lastTimestamp';
  static const String lastLatitude = 'lastLatitude';
  static const String lastLongitude = 'lastLongitude';
  static const String lastHeading = 'lastHeading';

  static Future<void> init() async {
    instance = await SharedPreferences.getInstance();
  }

  static Future<void> migrate() async {
    if (Platform.isAndroid) {
      final intervalValue = instance.getString(interval);
      if (intervalValue != null) {
        await instance.setInt(interval, int.tryParse(intervalValue) ?? 300);
        await instance.remove(interval);
      }
      
      final distanceValue = instance.getString(distance);
      if (distanceValue != null) {
        final intValue = int.tryParse(distanceValue) ?? 75;
        await instance.setInt(distance, intValue > 0 ? intValue : 75);
        await instance.remove(distance);
      }
      
      final angleValue = instance.getString(angle);
      if (angleValue != null) {
        final intValue = int.tryParse(angleValue) ?? 0;
        await instance.setInt(angle, intValue);
        await instance.remove(angle);
      }
    } else {
      await _migrate();
    }
    
    if (instance.getString(id) == null) {
      await instance.setString(id, (Random().nextInt(90000000) + 10000000).toString());
    }
    
    if (instance.getString(url) == null) {
      await instance.setString(url, 'http://demo.traccar.org:5055');
    }
    
    if (instance.getString(accuracy) == null) {
      await instance.setString(accuracy, 'medium');
    }
    
    if (instance.getInt(interval) == null) {
      await instance.setInt(interval, 300);
    }
    
    if (instance.getInt(distance) == null) {
      await instance.setInt(distance, 75);
    }
    
    if (instance.getBool(buffer) == null) {
      await instance.setBool(buffer, true);
    }
    
    if (instance.getBool(stopDetection) == null) {
      await instance.setBool(stopDetection, true);
    }
    
    if (instance.getBool(autoEnableTracking) == null) {
      await instance.setBool(autoEnableTracking, true);
    }
    
    if (instance.getInt(fastestInterval) == null) {
      await instance.setInt(fastestInterval, 30);
    }
  }



  // ignore: unused_element
  static String? _formatUrl(String? url) {
    if (url == null) return null;
    final uri = Uri.parse(url);
    if ((uri.path.isEmpty || uri.path == '') && !url.endsWith('/')) return '$url/';
    return url;
  }



  static Future<void> _migrate() async {
    final oldId = instance.getString('device_id_preference');
    if (oldId != null) {
      await instance.setString(id, oldId);
      await instance.remove('device_id_preference');
    }
    
    final oldUrl = instance.getString('server_url_preference');
    if (oldUrl != null) {
      await instance.setString(url, oldUrl);
      await instance.remove('server_url_preference');
    }
    
    final oldAccuracy = instance.getString('accuracy_preference');
    if (oldAccuracy != null) {
      await instance.setString(accuracy, oldAccuracy);
      await instance.remove('accuracy_preference');
    }
    
    final oldIntervalString = instance.getString('frequency_preference');
    if (oldIntervalString != null) {
      final oldInterval = int.tryParse(oldIntervalString);
      if (oldInterval != null) {
        await instance.setInt(interval, oldInterval);
      }
      await instance.remove('frequency_preference');
    }
    
    final oldDistanceString = instance.getString('distance_preference');
    if (oldDistanceString != null) {
      final oldDistance = int.tryParse(oldDistanceString);
      if (oldDistance != null) {
        await instance.setInt(distance, oldDistance > 0 ? oldDistance : 75);
      }
      await instance.remove('distance_preference');
    }
    
    final oldBuffer = instance.getBool('buffer_preference');
    if (oldBuffer != null) {
      await instance.setBool(buffer, oldBuffer);
      await instance.remove('buffer_preference');
    }
  }
}
