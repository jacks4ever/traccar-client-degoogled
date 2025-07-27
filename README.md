# Traccar Client - De-Googled Android Version

## 🚫 De-Googled Android GPS Tracker

This is a modified version of the Traccar Client app with **all Google dependencies removed**, designed specifically for **Android devices only**. Perfect for:

- 📱 Android phones without Google Play Services
- 🔒 Custom ROMs (LineageOS, GrapheneOS, CalyxOS, etc.)
- 🛡️ Privacy-focused devices like Unplugged phones
- 🚫 Users who want to completely avoid Google services
- 🔓 De-googled Android installations

**Key Features:**
- ❌ **Zero Google Dependencies** - No Firebase, no Google Play Services
- ❌ **No iOS Support** - Android-only for maximum compatibility
- ✅ **HTTP Polling** - Replaces Firebase push notifications
- ✅ **Custom Error Logging** - No data sent to Google
- ✅ **Universal Android Support** - Works on any Android device
- ✅ **Privacy First** - Your data stays on your server

## Download

🚀 **[Download Latest APK](../../releases/download/v9.5.3-degoogled/traccar-client-degoogled-v9.5.3.apk)** (38.2MB) - **Full degoogled support!**

✨ **Latest Version: v9.5.3-degoogled**
- ✅ **Complete degoogled device support** - Works perfectly on Unplugged phones
- ✅ **Enhanced error handling** - No more "Google Play Services" crashes
- ✅ **Native Android location services** - Uses device's built-in GPS
- ✅ **Universal APK** - Compatible with all Android architectures
- ✅ **Improved stability** - Better dependency management

🔗 **[View All Releases](../../releases)** - See release notes and previous versions

### Installation Troubleshooting
If you get "App not installed" or "package appears to be invalid" errors:
1. Enable **Unknown Sources** in Settings → Security
2. Clear any previous installation attempts
3. Restart your device and try again
4. Make sure you have enough storage space (40MB+ free)

See [DEGOOGLED_CHANGES.md](DEGOOGLED_CHANGES.md) for detailed technical information.

## Overview

Traccar Client is a GPS tracking app for Android devices. It runs in the background and sends location updates to your own server using the open-source Traccar platform.

- **Real-time Tracking**: See your device’s location on your private server in real time.
- **Open-Source**: 100% free and open-source, with no ads or tracking.
- **Customizable**: Configure update intervals, accuracy, and data usage to fit your needs.
- **Privacy First**: Your location data is sent only to your chosen server—never to third parties or Google.
- **Easy Integration**: Designed to work seamlessly with the Traccar server and many third-party GPS tracking platforms.
- **De-Googled Compatible**: Works perfectly on phones without Google Play Services.

Just enter your server address, grant location permissions, and the app will automatically send periodic location reports in the background.

## Installation

1. **Download** the APK from the [releases page](../../releases/latest)
2. **Enable** "Install from unknown sources" in your Android settings
3. **Install** the APK file
4. **Configure** your Traccar server URL and device ID
5. **Grant** location permissions
6. **Start** tracking!

Works on all Android versions and custom ROMs without requiring Google services.

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
