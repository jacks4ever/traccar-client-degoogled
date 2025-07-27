import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:traccar_client/degoogled_geolocation_service.dart';
import 'package:traccar_client/push_service.dart';
import 'package:traccar_client/quick_actions.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;

import 'l10n/app_localizations.dart';
import 'main_screen.dart';
import 'preferences.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> _requestLocationPermissions() async {
  try {
    // Request location permissions using the background geolocation plugin
    final status = await bg.BackgroundGeolocation.requestPermission();
    developer.log('Location permission status: $status');
    
    // If permission is granted, also request background location permission
    if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS || 
        status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE) {
      developer.log('Location permissions granted');
    } else {
      developer.log('Location permissions denied or not granted');
    }
  } catch (error) {
    developer.log('Error requesting location permissions', error: error);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up custom error handling instead of Firebase Crashlytics
  FlutterError.onError = (FlutterErrorDetails details) {
    developer.log('Flutter Error: ${details.exception}', 
                  error: details.exception, 
                  stackTrace: details.stack);
  };
  
  await Preferences.init();
  await Preferences.migrate();
  await DegoogledGeolocationService.init();
  await PushService.init();
  
  // Request location permissions on first launch
  await _requestLocationPermissions();
  
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  RateMyApp rateMyApp = RateMyApp(minDays: 0, minLaunches: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await rateMyApp.init();
      if (mounted && rateMyApp.shouldOpenDialog) {
        try {
          await rateMyApp.showRateDialog(context);
        } catch (error) {
          developer.log('Failed to show rate dialog', error: error);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: messengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      home: Stack(
        children: const [
          QuickActionsInitializer(),
          MainScreen(),
        ],
      ),
    );
  }
}
