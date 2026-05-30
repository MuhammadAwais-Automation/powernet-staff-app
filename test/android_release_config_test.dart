import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release Android manifest can launch MainActivity and use network', () {
    final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
    final namespace = RegExp(
      r'namespace\s*=\s*"([^"]+)"',
    ).firstMatch(buildGradle)?.group(1);
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final mainActivity = File(
      'android/app/src/main/kotlin/com/powernet/powernet_staff/MainActivity.kt',
    ).readAsStringSync();
    final packageName = RegExp(
      r'package\s+([^\s]+)',
    ).firstMatch(mainActivity)?.group(1);

    expect(namespace, isNotNull);
    expect(packageName, namespace);
    expect(
      manifest,
      contains('android.permission.INTERNET'),
      reason: 'Release APK needs network access for Supabase and Google Fonts.',
    );
  });
}
