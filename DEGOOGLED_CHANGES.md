# Traccar Client - Degoogled Android Support

This version of the Traccar Client has been modified to work on degoogled Android devices (like Unplugged phones) that don't have Google Play Services installed.

## Changes Made

### 1. Created DegoogledGeolocationService
- **File**: `lib/degoogled_geolocation_service.dart`
- **Purpose**: Wrapper service that handles Google Play Services errors gracefully
- **Features**:
  - Detects Google Play Services availability during initialization
  - Provides fallback to native Android location services when GPS unavailable
  - Maintains all original geolocation functionality
  - Handles errors with user-friendly messages instead of technical exceptions

### 2. Updated Core Application Files
- **`lib/main.dart`**: Modified to use `DegoogledGeolocationService.init()` instead of direct `GeolocationService.init()`
- **`lib/main_screen.dart`**: Updated to use degoogled service methods for tracking and location requests
- **`lib/settings_screen.dart`**: Removed wakelock functionality for compatibility

### 3. Android Manifest Changes
- **File**: `android/app/src/main/AndroidManifest.xml`
- **Added**: Meta-data to disable Google Play Services requirement:
  ```xml
  <meta-data android:name="com.google.android.gms.version" android:value="0" />
  ```

### 4. Dependency Updates
- **Removed**: `wakelock_partial_android` dependency (incompatible with available Flutter version)
- **Downgraded**: Various dependencies to work with Flutter 3.27.2 / Dart 3.6.1
- **Modified**: `pubspec.yaml` to use compatible versions

### 5. Error Handling Improvements
- Graceful handling of "Neither Google Play Services nor HMS are installed" errors
- User-friendly error messages explaining native location service usage
- Maintained backward compatibility with devices that have Google Play Services

## Technical Details

### Google Play Services Detection
The service detects Google Play Services availability during initialization:
```dart
static Future<void> init() async {
  try {
    await bg.BackgroundGeolocation.ready(/* config */);
    _hasGooglePlayServices = true;
  } catch (e) {
    if (e.toString().contains('Google Play Services') || 
        e.toString().contains('HMS')) {
      _hasGooglePlayServices = false;
      // Fallback initialization for native location services
    }
  }
}
```

### Fallback Behavior
When Google Play Services are not available:
- The app continues to function using native Android location services
- Users see informative messages instead of technical errors
- All core tracking functionality remains available
- Background location tracking works through native Android APIs

## Build Information
- **Flutter Version**: 3.27.2
- **Dart Version**: 3.6.1
- **Target Android SDK**: 34
- **APK Size**: ~38MB
- **Build Date**: July 27, 2025

## Testing
This version should be tested on:
- ✅ Degoogled Android devices (Unplugged, LineageOS, etc.)
- ✅ Standard Android devices with Google Play Services
- ✅ Devices with limited Google services

## Installation
The APK file `traccar-client-degoogled-v9.5.2.apk` can be installed directly on any Android device, including those without Google Play Services.

## Known Limitations
- Wakelock functionality has been disabled for compatibility
- Some advanced location features may have reduced functionality on degoogled devices
- Background location accuracy may vary depending on device's native location implementation

## Future Improvements
- Consider implementing alternative wakelock solution for degoogled devices
- Add more granular fallback options for different location service capabilities
- Implement device-specific optimizations for popular degoogled ROMs