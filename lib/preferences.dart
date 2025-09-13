import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static final Preferences instance = Preferences._internal();
  static SharedPreferences? _prefs;

  // Preference keys
  static const String id = 'device_id';
  static const String url = 'server_url';
  static const String accuracy = 'location_accuracy';
  static const String interval = 'update_interval';
  static const String distance = 'distance_filter';
  static const String buffer = 'buffer_preference';
  static const String fastestInterval = 'fastest_interval';
  static const String angle = 'angle';
  static const String heartbeat = 'heartbeat';
  static const String wakelock = 'wakelock';
  static const String stopDetection = 'stop_detection';

  Preferences._internal();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> migrate() async {
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

  static String? _formatUrl(String? url) {
    if (url == null) return null;
    final uri = Uri.parse(url);
    if ((uri.path.isEmpty || uri.path == '') && !url.endsWith('/')) return '$url/';
    return url;
  }

  String? getString(String key) => _prefs?.getString(key);
  int? getInt(String key) => _prefs?.getInt(key);
  bool? getBool(String key) => _prefs?.getBool(key);

  Future<void> setString(String key, String value) async => await _prefs?.setString(key, value);
  Future<void> setInt(String key, int value) async => await _prefs?.setInt(key, value);
  Future<void> setBool(String key, bool value) async => await _prefs?.setBool(key, value);

  Future<void> clear() async => await _prefs?.clear();
}
