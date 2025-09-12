# P2P File Share

A cross-platform peer-to-peer file sharing application built with Flutter. Share files directly between devices on the same local network without requiring an internet connection.

## Features

- **Local Network Discovery**: Automatically discover nearby devices using mDNS
- **Cross-Platform**: Works on Android, iOS, macOS, and Windows
- **Secure Transfers**: Direct peer-to-peer connections with optional encryption
- **Fast Speeds**: No internet bandwidth limitations
- **Any File Type**: Share photos, videos, documents, APKs, and more
- **Real-time Progress**: Live transfer progress with speed and ETA
- **Dark Mode**: Full dark theme support
- **Transfer History**: Track completed and failed transfers

## Screenshots

*Screenshots would be added here showing the main screens*

## Installation

### Prerequisites

- Flutter SDK (3.9.0 or higher)
- Dart SDK
- Platform-specific development tools:
  - **Android**: Android Studio with Android SDK
  - **iOS**: Xcode (macOS only)
  - **macOS**: Xcode
  - **Windows**: Visual Studio with C++ tools

### Setup

1. **Clone the repository**
   \`\`\`bash
   git clone <repository-url>
   cd p2p_file_share
   \`\`\`

2. **Install dependencies**
   \`\`\`bash
   flutter pub get
   \`\`\`

3. **Platform-specific setup**

   #### Android
   - No additional setup required
   - The app will request storage permissions at runtime

   #### iOS
   - Add network permissions to `ios/Runner/Info.plist`:
   \`\`\`xml
   <key>NSLocalNetworkUsageDescription</key>
   <string>This app uses local network to discover and connect to nearby devices for file sharing.</string>
   <key>NSBonjourServices</key>
   <array>
       <string>_p2pfileshare._tcp</string>
   </array>
   \`\`\`

   #### macOS
   - Enable network and file access permissions in `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`. If your app is sandboxed, these are required:
   \`\`\`xml
   <!-- For networking -->
   <key>com.apple.security.network.client</key>
   <true/>
   <key>com.apple.security.network.server</key>
   <true/>

   <!-- For picking files -->
   <key>com.apple.security.files.user-selected.read-only</key>
   <true/>

   <!-- For saving files to the Downloads folder -->
   <key>com.apple.security.files.downloads.read-write</key>
   <true/>
   \`\`\`

   #### Windows
   - No additional setup required
   - Windows Defender may prompt for network access

## Usage

### Basic File Sharing

1. **Start the app** on both devices
2. **Connect to the same Wi-Fi network**
3. **Enable "Make Discoverable"** in settings (enabled by default)
4. **Wait for devices to appear** on the home screen
5. **Tap a device** and select files to send
6. **Accept incoming files** when prompted

### Manual Connection

If automatic discovery doesn't work:

1. Tap the **menu button** (⋮) on the home screen
2. Select **"Manual Connect"**
3. Enter the **IP address and port** of the target device
4. Tap **"Connect"**

### Settings Configuration

- **Device Name**: Change how your device appears to others
- **Port**: Modify the network port (default: 8080)
- **Auto Accept**: Automatically accept incoming files (security warning applies)
- **Dark Mode**: Toggle between light and dark themes
- **Default Save Folder**: Choose where received files are saved

## Architecture

The app follows a clean architecture pattern with the following structure:

\`\`\`
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── device.dart
│   └── file_transfer.dart
├── services/                 # Business logic
│   ├── discovery_service.dart
│   ├── transfer_service.dart
│   ├── settings_service.dart
│   ├── notification_service.dart
│   └── file_storage_service.dart
├── screens/                  # UI screens
│   ├── main_screen.dart
│   ├── home_screen.dart
│   ├── send_file_screen.dart
│   ├── transfers_screen.dart
│   ├── settings_screen.dart
│   └── about_screen.dart
├── widgets/                  # Reusable UI components
└── theme/                    # App theming
\`\`\`

### Key Services

- **DiscoveryService**: Handles device discovery using mDNS
- **TransferService**: Manages file transfers over TCP sockets
- **SettingsService**: Persists user preferences
- **NotificationService**: Shows system notifications
- **FileStorageService**: Handles file system operations

## Testing

Run the test suite:

\`\`\`bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Test coverage
flutter test --coverage
\`\`\`

### Test Structure

- **Unit Tests**: Test individual services and models
- **Widget Tests**: Test UI components
- **Integration Tests**: Test complete workflows

## Building

### Development

\`\`\`bash
# Run in debug mode
flutter run

# Run on specific platform
flutter run -d android
flutter run -d ios
flutter run -d macos
flutter run -d windows
\`\`\`

### Production

\`\`\`bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release
\`\`\`

## Troubleshooting

### Common Issues

**Devices not appearing**
- Ensure both devices are on the same Wi-Fi network
- Check that "Make Discoverable" is enabled
- Try manual connection with IP address
- Restart the app

**Transfer failures**
- Check network connectivity
- Verify firewall settings (especially on Windows/macOS)
- Ensure sufficient storage space
- Try a different port in settings

**Permission errors**
- Grant storage permissions on mobile devices
- Check network permissions on desktop platforms
- Verify file access permissions

### Platform-Specific Notes

**Android**
- Requires storage permission for file access
- May need to disable battery optimization for background transfers

**iOS**
- Limited background processing
- Files saved to app's document directory

**macOS**
- May require network permission approval
- Gatekeeper might block unsigned builds

**Windows**
- Windows Defender may flag the app initially
- Firewall permission required for network access

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the excellent framework
- Community packages used in this project
- Contributors and testers

## Support

For issues and questions:
- Check the troubleshooting section above
- Search existing GitHub issues
- Create a new issue with detailed information

---

**Note**: This app is designed for local network file sharing. No data is sent over the internet, ensuring privacy and security of your files.
