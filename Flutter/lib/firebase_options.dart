// File generated for Firebase project farvixo-production-2026.
// Matches FlutterFire CLI output shape (Android + Web).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS — '
          'add GoogleService-Info.plist from Firebase Console.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCW6-ik0yBIkrHH2ScoZFEFD3u5qhUS5SU',
    appId: '1:282376161241:web:d0bca9dcc89c299e1f7bc8',
    messagingSenderId: '282376161241',
    projectId: 'farvixo-production-2026',
    authDomain: 'farvixo-production-2026.firebaseapp.com',
    storageBucket: 'farvixo-production-2026.firebasestorage.app',
    measurementId: 'G-VTGV5YE47C',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHLQNCybE5BY4KJKPlcMIw91MsFK-8qRM',
    appId: '1:282376161241:android:24f8d9a3431ca6b81f7bc8',
    messagingSenderId: '282376161241',
    projectId: 'farvixo-production-2026',
    storageBucket: 'farvixo-production-2026.firebasestorage.app',
  );
}
