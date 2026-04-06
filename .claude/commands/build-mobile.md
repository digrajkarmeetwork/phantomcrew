# Build Mobile — Phantom Crew Flutter Build Validator

Build, analyse, and validate the Phantom Crew Flutter mobile app for Android and/or iOS.

## Workflow

Make a todo list and work through each step sequentially.

### 1. Verify Flutter Environment

```bash
flutter --version
flutter doctor --verbose
```

Check output for:
- Flutter SDK version ≥ 3.16
- Dart SDK version ≥ 3.2
- Android toolchain: Android SDK, cmdline-tools, build-tools
- iOS toolchain (only required for iOS builds): Xcode, CocoaPods

Report any issues found by `flutter doctor` before proceeding. Do not continue if there
are critical errors in the toolchain the user needs.

### 2. Install Dependencies

```bash
cd phantom-crew   # or the Flutter project root — check CLAUDE.md Section 9
flutter pub get
```

If `pubspec.yaml` doesn't exist yet, the Flutter project hasn't been initialised.
Tell the user to run `/add-task` or create the project first.

### 3. Static Analysis

```bash
flutter analyze
```

Zero errors required. Warnings are acceptable but should be noted.
If there are errors, fix them before proceeding.

### 4. Run Tests

```bash
flutter test
```

All tests must pass. If any fail, investigate and fix before building.

### 5. Check Asset References

Verify that all assets listed in `pubspec.yaml` under `flutter.assets` actually exist on disk.

```bash
# Quick check — list declared assets vs actual files
```

Read `pubspec.yaml`, extract the assets list, and verify each path exists.
Report any missing assets — these will cause a build failure.

### 6. Build Android Debug (Fast Validation)

```bash
flutter build apk --debug
```

Confirm the APK was produced at `build/app/outputs/flutter-apk/app-debug.apk`.
Report the file size.

### 7. Build Android Release (if user requested release build)

```bash
flutter build apk --release --split-per-abi
```

This produces separate APKs for arm64-v8a, armeabi-v7a, x86_64.
APKs will be at `build/app/outputs/flutter-apk/`.

For an AAB (Google Play Store):
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

### 8. Build iOS (only if on macOS with Xcode)

```bash
flutter build ios --release --no-codesign
```

Note: A fully signed iOS build requires:
- Apple Developer account
- Provisioning profiles configured in Xcode
- CocoaPods installed

If not on macOS, skip and note that iOS builds require a Mac.

### 9. Test on Device/Emulator (optional)

If a device or emulator is connected:
```bash
flutter devices              # list available devices
flutter run --release        # run release build on first connected device
```

### 10. Relay Server Check

```bash
cd relay-server
npm install
node -e "const s = require('./server.js'); setTimeout(() => { console.log('Relay OK'); process.exit(0); }, 1000);"
```

Verify the relay server still starts correctly.

### 11. Summary Report

Provide a build report:
```
✅/❌ flutter analyze  — N errors, N warnings
✅/❌ flutter test     — N tests passed, N failed
✅/❌ Android debug APK — X.X MB at path/to/app-debug.apk
✅/❌ Android release APK — X.X MB
✅/❌ iOS build         — (skipped / passed / failed)
✅/❌ Relay server      — starts OK
```

## Common Issues & Fixes

**`flutter pub get` fails with dependency conflict**
→ Run `flutter pub upgrade` to update to compatible versions.

**Missing assets causing build failure**
→ Run `/generate-assets` to create missing assets, then add them to `pubspec.yaml`.

**Android build fails: SDK not found**
→ Run `flutter doctor` and follow Android SDK setup instructions.

**iOS build fails: CocoaPods not installed**
→ `sudo gem install cocoapods && cd ios && pod install`

**Relay server port already in use**
→ `lsof -ti:3000 | xargs kill -9` then retry.
