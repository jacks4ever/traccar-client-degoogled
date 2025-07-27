# [Traccar Client app - De-Googled Version](https://www.traccar.org/client)

## 🚫 De-Googled Version

This is a modified version of the Traccar Client app with **all Google dependencies removed**, making it suitable for:
- Android phones without Google Play Services
- Custom ROMs (LineageOS, GrapheneOS, etc.)
- Privacy-focused devices like Unplugged phones
- Users who want to avoid Google services

**Key Changes:**
- ❌ Removed Firebase (messaging, analytics, crashlytics)
- ❌ Removed Google Play Services dependencies
- ✅ Replaced push notifications with HTTP polling
- ✅ Added custom error logging
- ✅ Works on all Android devices, with or without Google services

See [DEGOOGLE_CHANGES.md](DEGOOGLE_CHANGES.md) for detailed information about the modifications.

## Overview

Traccar Client is a GPS tracking app for Android and iOS. It runs in the background and sends location updates to your own server using the open-source Traccar platform.

- **Real-time Tracking**: See your device’s location on your private server in real time.
- **Open-Source**: 100% free and open-source, with no ads or tracking.
- **Customizable**: Configure update intervals, accuracy, and data usage to fit your needs.
- **Privacy First**: Your location data is sent only to your chosen server—never to third parties.
- **Easy Integration**: Designed to work seamlessly with the Traccar server and many third-party GPS tracking platforms.

Just enter your server address, grant location permissions, and the app will automatically send periodic location reports in the background.

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
