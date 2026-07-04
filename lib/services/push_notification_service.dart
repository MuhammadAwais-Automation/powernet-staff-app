import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/follow_up_repository.dart';

typedef PushAlertHandler = void Function(String title, String body, Map<String, String> data);

/// Registers staff device tokens for FCM push delivery.
class PushNotificationService {
  final FollowUpRepository _repo = FollowUpRepository();
  bool _initialized = false;

  Future<String?> requestToken() async {
    if (kIsWeb) return null;
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return messaging.getToken();
    } catch (e) {
      debugPrint('PushNotificationService token error: $e');
      return null;
    }
  }

  Future<void> initializeForStaff({
    required String staffId,
    String? fcmToken,
  }) async {
    if (kIsWeb) return;
    final token = (fcmToken ?? await requestToken())?.trim();
    if (token == null || token.isEmpty) {
      debugPrint('PushNotificationService: no FCM token — skipping registration');
      return;
    }
    final platform = kIsWeb
        ? 'web'
        : defaultTargetPlatform == TargetPlatform.iOS
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

  Future<void> bindStaffSession({
    required String staffId,
    required PushAlertHandler onAlert,
    void Function(Map<String, String> data)? onOpen,
  }) async {
    if (kIsWeb) return;
    await initializeForStaff(staffId: staffId);

    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      initializeForStaff(staffId: staffId, fcmToken: token);
    });

    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'PowerNet Alert';
      final body = message.notification?.body ?? '';
      onAlert(title, body, _messageData(message));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onOpen?.call(_messageData(message));
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      onOpen?.call(_messageData(initial));
    }
  }

  Map<String, String> _messageData(RemoteMessage message) {
    return message.data.map((key, value) => MapEntry(key, value.toString()));
  }

  RealtimeChannel? subscribeComplaintAlerts({
    required String staffId,
    required PushAlertHandler onAlert,
  }) {
    final channel = Supabase.instance.client
        .channel('staff-complaint-alerts-$staffId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'complaints',
          callback: (payload) {
            final row = _rowMap(payload.newRecord);
            if (row.isEmpty) return;

            final assignedTo = row['assigned_to'] as String?;
            final teamId = row['team_id'] as String?;
            if (assignedTo != staffId && (teamId == null || teamId.isEmpty)) {
              return;
            }

            final code = row['complaint_code'] as String? ?? 'Complaint';
            final issue = row['issue'] as String? ?? '';
            onAlert(
              'Assigned: $code',
              issue,
              {
                'type': 'complaint_assigned',
                'complaintId': row['id']?.toString() ?? '',
              },
            );
          },
        )
        .subscribe();
    return channel;
  }

  Map<String, dynamic> _rowMap(Map<String, dynamic> record) {
    return record.map((key, value) => MapEntry(key, value));
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.notification?.title}');
}