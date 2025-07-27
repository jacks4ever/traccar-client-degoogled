# De-Googled Traccar Client Changes

This document outlines the changes made to remove Google dependencies from the Traccar client app, making it suitable for Android phones like Unplugged that don't have Google Play Services.

## Changes Made

### 1. Removed Firebase Dependencies

**Files Removed:**
- `lib/firebase_options.dart` - Firebase configuration
- `android/app/google-services.json` - Google Services configuration for Android
- `ios/Runner/GoogleService-Info.plist` - Google Services configuration for iOS
- `firebase.json` - Firebase project configuration

**Dependencies Removed from `pubspec.yaml`:**
- `firebase_core: ^3.15.2`
- `firebase_messaging: ^15.2.10`
- `firebase_analytics: ^11.5.2`
- `firebase_crashlytics: ^4.3.10`

**Dependencies Added:**
- `http: ^1.2.2` - For HTTP requests in the new push service

### 2. Updated Main Application (`lib/main.dart`)

**Changes:**
- Removed Firebase imports and initialization
- Replaced Firebase Crashlytics with custom error logging using `developer.log()`
- Removed `Firebase.initializeApp()` call
- Added custom `FlutterError.onError` handler

### 3. Replaced Push Service (`lib/push_service.dart`)

**Old Implementation:**
- Used Firebase Cloud Messaging (FCM) for push notifications
- Required Google Play Services
- Real-time push notifications

**New Implementation:**
- HTTP polling-based command checking
- Polls server every 5 minutes for pending commands
- No dependency on Google services
- Supports the same commands: `positionSingle`, `positionPeriodic`, `positionStop`, `factoryReset`

**Key Features:**
- Automatic polling when geolocation is enabled
- Configurable poll interval (currently 5 minutes)
- Device registration with server indicating polling mode
- Graceful error handling and logging

### 4. Android Build Configuration

**Files Modified:**
- `android/app/build.gradle.kts` - Removed Google Services and Firebase Crashlytics plugins
- `android/settings.gradle.kts` - Removed Google Services and Firebase Crashlytics plugin declarations
- `android/build.gradle.kts` - Removed Play Services Location version reference

**Plugins Removed:**
- `com.google.gms.google-services`
- `com.google.firebase.crashlytics`

## Impact on Functionality

### What Still Works:
- Location tracking and reporting
- All geolocation features
- Device commands (via polling)
- App settings and configuration
- QR code scanning
- All UI functionality

### What Changed:
- **Push Notifications**: Now uses HTTP polling instead of real-time push
- **Command Delivery**: Commands are delivered within 5 minutes instead of instantly
- **Error Reporting**: Uses local logging instead of Firebase Crashlytics
- **Analytics**: No analytics data is sent to Google

### Battery Impact:
- Minimal additional battery usage from 5-minute polling
- Polling only occurs when location tracking is enabled
- Much more battery-efficient than keeping Google Play Services running

## Server-Side Considerations

The new polling-based push service expects the server to support:
- `GET /api/commands/pending?deviceId={id}` - Returns pending commands for device
- `POST /api/devices/register` - Registers device with polling configuration

If your Traccar server doesn't support these endpoints, the app will still function normally for location tracking, but remote commands won't work.

## Benefits for De-Googled Devices

1. **No Google Play Services Required**: Works on phones without Google services
2. **Privacy**: No data sent to Google servers
3. **Compatibility**: Works on custom ROMs and privacy-focused devices
4. **Open Source Friendly**: Removes proprietary Google dependencies
5. **Reduced Permissions**: No longer requires Google-specific permissions

## Installation on De-Googled Devices

This version can be installed on:
- Phones with custom ROMs (LineageOS, GrapheneOS, etc.)
- Devices without Google Play Services
- Privacy-focused Android distributions
- Standard Android devices (works as a drop-in replacement)

The app will work identically to the original version, with the only difference being the polling-based command delivery instead of instant push notifications.