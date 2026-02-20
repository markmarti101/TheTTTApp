// Firebase config for The Training Triangle
// For full setup: run `dart run flutterfire_cli:flutterfire configure`

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAVISBFPZ7vcIJrV1qLvUoqNFPIL4id87U',
    appId: '1:861837788735:web:7b858039d08984fc4e1a8a',
    messagingSenderId: '861837788735',
    projectId: 'training-triangle-app',
    authDomain: 'training-triangle-app.firebaseapp.com',
    storageBucket: 'training-triangle-app.firebasestorage.app',
  );

  // Add Android app in Firebase Console, then run:
  // dart run flutterfire_cli:flutterfire configure
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAVISBFPZ7vcIJrV1qLvUoqNFPIL4id87U',
    appId: '1:861837788735:android:7b858039d08984fc4e1a8a',
    messagingSenderId: '861837788735',
    projectId: 'training-triangle-app',
    storageBucket: 'training-triangle-app.firebasestorage.app',
  );

  // Add iOS app in Firebase Console, then run:
  // dart run flutterfire_cli:flutterfire configure
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVISBFPZ7vcIJrV1qLvUoqNFPIL4id87U',
    appId: '1:861837788735:ios:7b858039d08984fc4e1a8a',
    messagingSenderId: '861837788735',
    projectId: 'training-triangle-app',
    storageBucket: 'training-triangle-app.firebasestorage.app',
  );
}
