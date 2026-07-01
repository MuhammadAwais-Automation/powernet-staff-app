import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/follow_up_repository.dart';

/// Registers staff device tokens for FCM push delivery.
class PushNotificationService {
  final FollowUpRepository _repo = FollowUpRepository();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<String?> requestToken() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return _messaging.getToken();
    } catch (e) {
      debugPrint('PushNotificationService token error: $e');
      return null;
    }
  }

  Future<void> initializeForStaff({
    required String staffId,
    String? fcmToken,
  }) async {
    final token = (fcmToken ?? await requestToken())?.trim();
    if (token == null || token.isEmpty) {
      debugPrint('PushNotificationService: no FCM token — skipping registration');
      return;
    }
    final platform = kIsWeb
        ? 'web'
        : Platform.isIOS
        ? 'ios'
        : 'android';
    try {
      await _repo.registerDeviceToken(
        staffId: staffId,
        token: token,
        platform: platform,
      );
    } on PostgrestException catch (e) {
      debugPrint('PushNotificationService register failed: ${e.message}');
    }
  }

  void listenForegroundAlerts({
    required void Function(String title, String body) onAlert,
  }) {
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'PowerNet Alert';
      final body = message.notification?.body ?? '';
      onAlert(title, body);
    });
  }

  RealtimeChannel? subscribeComplaintAlerts({
    required void Function(String title, String body) onAlert,
  }) {
    final channel = Supabase.instance.client
        .channel('staff-complaint-alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'complaints',
          callback: (payload) {
            final row = payload.newRecord;
            final code = row['complaint_code'] as String? ?? 'New complaint';
            final issue = row['issue'] as String? ?? '';
            onAlert('New complaint $code', issue);
          },
        )
        .subscribe();
    return channel;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.notification?.title}');
}