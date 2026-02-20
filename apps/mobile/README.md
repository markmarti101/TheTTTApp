# The Training Triangle — Flutter Mobile App

## Run the app

```bash
# From project root
npm run dev:mobile

# Or directly
cd apps/mobile
flutter run
```

**iOS:**
```bash
flutter run -d ios
# or: npm run mobile:ios
```

**Android:**
```bash
flutter run -d android
# or: npm run mobile:android
```

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Xcode (for iOS)
- Android Studio (for Android)
- Firebase project configured (see [FIREBASE_SETUP.md](../../docs/FIREBASE_SETUP.md))

## Firebase

1. Add Android and iOS apps in Firebase Console
2. Place `google-services.json` in `android/app/`
3. Place `GoogleService-Info.plist` in `ios/Runner/`
4. Enable Email/Password auth and create Firestore `users` collection
