import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for PowerNet Staff (project: first-demo-53c4b).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web push is not configured for PowerNet Staff.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS Firebase is not configured yet.');
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase is only configured for Android in PowerNet Staff.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAv1XdZCS9DAXkjVO7mzKomeObxqAYkJSM',
    appId: '1:919233009146:android:858e9a00b189228ddb4043',
    messagingSenderId: '919233009146',
    projectId: 'first-demo-53c4b',
    storageBucket: 'first-demo-53c4b.firebasestorage.app',
  );
}