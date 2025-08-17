# Traccar Client - Degoogled Edition

> A fully degoogled GPS tracking client for Android with native AOSP location services, pre-configured demo server, and complete Google Play Services independence.

## 🚫 Degoogled Android GPS Tracker

This is a modified version of the Traccar Client app with **all Google dependencies removed**, designed specifically for **Android devices only**. Perfect for:

- 📱 Android phones without Google Play Services
- 🔒 Custom ROMs (LineageOS, GrapheneOS, CalyxOS, LibertOS, etc.)
- 🛡️ Privacy-focused devices like Unplugged phones
- 🚫 Users who want to completely avoid Google services
- 🔓 Degoogled Android installations

**Key Features:**
- ❌ **Zero Google Dependencies** - No Firebase, no Google Play Services
- ✅ **Native GPS** - Uses Android's native AOSP GPS hardware
- ✅ **Demo Server Ready** - Pre-configured with Traccar Demo Server
- ✅ **Battery Monitoring** - Reports battery level to server
- ✅ **Fresh GPS Updates** - Manual GPS refresh functionality
- ✅ **Universal Android Support** - Works on any Android device
- ✅ **Privacy First** - Your data stays on your server

## Download

🚀 **[Download Latest APK](../../releases/latest)** - **Enhanced Continuous Tracking!**

✨ **Latest Version: v9.5.2e** - **Enhanced Continuous Tracking Edition**
- 🔄 **Continuous Fresh GPS** - Automatic fresh GPS readings every 5min (stationary) or 2min (moving)
- 🎯 **Movement-Adaptive Tracking** - Intelligent intervals that adjust based on movement detection
- 💓 **Enhanced Heartbeat** - Location-enabled heartbeats ensure server always has fresh data
- ⚡ **Immediate GPS on Start** - Fresh GPS reading sent instantly when tracking begins
- 🛡️ **Improved Reliability** - Better GPS failure handling with smart fallback mechanisms
- 🔋 **Battery Optimized** - Less frequent updates when stationary, more when moving
- ✅ **All Previous Features** - GPS location fix, battery reporting, demo server ready
- ✅ **Universal Compatibility** - Works on all degoogled Android devices

🔗 **[View All Releases](../../releases)** - See release notes and previous versions

### Installation Troubleshooting
If you get "App not installed" or "package appears to be invalid" errors:
1. Enable **Unknown Sources** in Settings → Security
2. Clear any previous installation attempts
3. Restart your device and try again
4. Make sure you have enough storage space (40MB+ free)

See [DEGOOGLED_CHANGES.md](DEGOOGLED_CHANGES.md) for detailed technical information and [CONTINUOUS_TRACKING_IMPROVEMENTS.md](CONTINUOUS_TRACKING_IMPROVEMENTS.md) for details about the enhanced tracking features.

## Overview

Traccar Client Degoogled Edition is a GPS tracking app for Android devices that runs completely without Google dependencies. It uses native Android location services and sends location updates to your own Traccar server.

- **Real-time Tracking**: See your device’s location on your private server in real time.
- **Native GPS**: Uses Android's built-in AOSP location manager (no Google Play Services)
- **Demo Server Ready**: Pre-configured with Traccar demo server for immediate testing
- **Battery Monitoring**: Reports device battery level along with location data
- **Fresh GPS Updates**: Manual GPS refresh button for accurate positioning
- **Privacy First**: Your location data is sent only to your chosen server—never to third parties or Google.
- **Easy Integration**: Designed to work seamlessly with the Traccar server and many third-party GPS tracking platforms.
- **Degoogled Compatible**: Specifically designed for phones without Google Play Services
- **Custom ROM Support**: Perfect for LineageOS, GrapheneOS, CalyxOS, LibertOS, and other privacy ROMs

Simply launch the app, grant location permissions, and it will automatically connect to the demo server. For custom servers, just enter your server address and device ID.

## 🔄 Enhanced Continuous Tracking (v9.5.2e)

This release introduces significant improvements to ensure reliable, continuous tracking:

- **🎯 Smart Intervals**: Automatically adjusts tracking frequency based on movement
  - 5-minute intervals when stationary (speed < 1 m/s)
  - 2-minute intervals when moving (speed ≥ 1 m/s)
- **💓 Enhanced Heartbeat**: Heartbeat messages now include GPS location data
- **⚡ Immediate Start**: Fresh GPS reading sent instantly when tracking begins
- **🛡️ Failure Recovery**: Improved handling of GPS failures with smart fallbacks
- **🔋 Battery Optimized**: Reduces unnecessary GPS usage when not moving

## Installation

1. **Download** the APK from the [releases page](../../releases/latest)
2. **Enable** "Install from unknown sources" in your Android settings
3. **Install** the APK file
4. **Grant** location permissions when prompted
5. **Start** tracking! (Demo server pre-configured)
6. **Optional**: Configure custom server URL and device ID in settings

Works on all Android versions and custom ROMs without requiring Google services. Perfect for degoogled devices including LineageOS, GrapheneOS, CalyxOS, LibertOS, and privacy-focused ROMs.

## Team

- Anton Tananaev ([anton@traccar.org](mailto:anton@traccar.org))

## License

    Apache License, Version 2.0

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
