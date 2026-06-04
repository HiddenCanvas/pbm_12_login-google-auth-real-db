// lib/services/fcm_service.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handler untuk notifikasi saat app di background / terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'pbm_high_importance';
  static const _channelName = 'PBM Notifications';

  static Future<void> initialize() async {
    // 1. Minta izin notifikasi
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 2. Setup local notifications (untuk foreground)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit),
    );

    // 3. Buat notification channel Android
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Notifikasi untuk PBM App',
            importance: Importance.high,
          ),
        );

    // 4. Handler background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 5. Handler foreground — tampilkan sebagai local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      if (notif != null) {
        _localNotif.show(
          notif.hashCode,
          notif.title,
          notif.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    // 6. Simpan token ke Supabase
    await saveTokenToSupabase();

    // 7. Refresh token otomatis
    _messaging.onTokenRefresh.listen((_) => saveTokenToSupabase());
  }

  /// Simpan / update FCM token device ini ke tabel fcm_tokens
  static Future<void> saveTokenToSupabase() async {
    final token = await _messaging.getToken();
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (token == null || userId == null) return;

    await Supabase.instance.client.from('fcm_tokens').upsert({
      'user_id': userId,
      'token': token,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');

    debugPrint('[FCM] Token saved for user: $userId');
  }

  /// Hapus token saat logout
  static Future<void> deleteToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final token = await _messaging.getToken();
    if (userId != null && token != null) {
      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('token', token);
    }
    await _messaging.deleteToken();
  }
}
