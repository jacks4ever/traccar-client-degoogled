// ignore_for_file: prefer_const_constructors

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rate_my_app/rate_my_app.dart';
import 'package:traccar_client/push_service.dart';
import 'package:traccar_client/quick_actions.dart';
import 'package:traccar_client/permission_setup_screen.dart';

import 'l10n/app_localizations.dart';
import 'simple_main_screen.dart';
import 'preferences.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

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
  await PushService.init();
  
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  RateMyApp rateMyApp = RateMyApp(minDays: 0, minLaunches: 0);
  bool _showPermissionSetup = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialSetup();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await rateMyApp.init();
      if (mounted && rateMyApp.shouldOpenDialog && !_showPermissionSetup) {
        try {
          await rateMyApp.showRateDialog(context);
        } catch (error) {
          developer.log('Failed to show rate dialog', error: error);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    developer.log('App lifecycle state changed to: $state');
    
    // This helps ensure location tracking continues when app goes to background
    switch (state) {
      case AppLifecycleState.paused:
        developer.log('App paused - location tracking should continue in background');
        break;
      case AppLifecycleState.resumed:
        developer.log('App resumed - checking location tracking status');
        break;
      case AppLifecycleState.detached:
        developer.log('App detached');
        break;
      case AppLifecycleState.inactive:
        developer.log('App inactive');
        break;
      case AppLifecycleState.hidden:
        developer.log('App hidden');
        break;
    }
  }

  Future<void> _checkInitialSetup() async {
    final setupCompleted = Preferences.instance.getBool('initial_setup_completed') ?? false;
    setState(() {
      _showPermissionSetup = !setupCompleted;
      _isLoading = false;
    });
  }

  void _onPermissionSetupComplete() {
    setState(() {
      _showPermissionSetup = false;
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
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _showPermissionSetup
              ? PermissionSetupScreen(onComplete: _onPermissionSetupComplete)
              : Stack(
                  children: const [
                    QuickActionsInitializer(),
                    SimpleMainScreen(),
                  ],
                ),
    );
  }
}
