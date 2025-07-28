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
    developer.log('🔐 STARTUP: Checking location permissions...');
    
    // Check current permission status first
    final providerState = await bg.BackgroundGeolocation.providerState;
    developer.log('Current location authorization status: ${providerState.status}');
    developer.log('GPS enabled: ${providerState.gps}, Network enabled: ${providerState.network}');
    
    // If permissions are not granted, request them
    if (providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED ||
        providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED) {
      
      developer.log('🚀 STARTUP: Requesting location permissions...');
      
      try {
        final status = await bg.BackgroundGeolocation.requestPermission();
        developer.log('Location permission request result: $status');
        
        if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS) {
          developer.log('✅ STARTUP: Location permissions granted - Always');
        } else if (status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE) {
          developer.log('⚠️ STARTUP: Location permissions granted - When In Use (may need background access)');
        } else {
          developer.log('❌ STARTUP: Location permissions denied: $status');
        }
      } catch (permissionError) {
        developer.log('❌ STARTUP: Permission request failed', error: permissionError);
        
        // If the background geolocation permission request fails, 
        // the user needs to manually grant permissions in Android settings
        developer.log('📱 STARTUP: User must manually grant location permissions in Android Settings');
      }
    } else if (providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS ||
               providerState.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE) {
      developer.log('✅ STARTUP: Location permissions already granted: ${providerState.status}');
    }
    
    // Final status check
    final finalState = await bg.BackgroundGeolocation.providerState;
    developer.log('🏁 STARTUP: Final permission status: ${finalState.status}');
    
  } catch (error) {
    developer.log('❌ STARTUP: Error checking location permissions', error: error);
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
      // Request location permissions first (after UI is ready)
      await _requestLocationPermissions();
      
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
