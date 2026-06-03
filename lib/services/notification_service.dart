// lib/services/notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;

  /// Ambil daftar semua user lain yang punya FCM token
  /// (untuk memilih siapa yang mau dikirimi notifikasi)
  static Future<List<Map<String, dynamic>>> getOtherUsersWithTokens() async {
    final currentUserId = _supabase.auth.currentUser?.id;

    // Join fcm_tokens dengan profiles (jika ada) atau pakai auth.users metadata
    final response = await _supabase
        .from('fcm_tokens')
        .select('user_id, token, updated_at')
        .neq('user_id', currentUserId ?? '');

    // Ambil nama dari metadata
    final List<Map<String, dynamic>> users = [];
    for (final row in response as List) {
      users.add({
        'user_id': row['user_id'],
        'token': row['token'],
        'display': 'User ${(row['user_id'] as String).substring(0, 8)}...',
      });
    }

    return users;
  }

  /// Kirim notifikasi ke SATU user tertentu (bukan yang lain)
  /// Inilah inti tugas: Perangkat A → B, tapi TIDAK ke C
  static Future<bool> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
  }) async {
    try {
      // Ambil token target
      final tokenData = await _supabase
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', targetUserId)
          .maybeSingle();

      if (tokenData == null) {
        debugPrint('[Notif] Target user tidak punya token');
        return false;
      }

      final targetToken = tokenData['token'] as String;
      final senderName =
          _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 'Seseorang';

      // Panggil Supabase Edge Function
      final result = await _supabase.functions.invoke(
        'send-notification',
        body: {
          'targetToken': targetToken,
          'title': title,
          'body': body,
          'senderName': senderName,
        },
      );

      debugPrint('[Notif] Berhasil dikirim. Response: ${result.data}');
      return true;
    } catch (e) {
      debugPrint('[Notif] Error: $e');
      return false;
    }
  }
}
