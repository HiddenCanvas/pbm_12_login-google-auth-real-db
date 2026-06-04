// lib/services/notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _supabase = Supabase.instance.client;

  /// Ambil daftar semua user lain yang punya FCM token
  /// (untuk memilih siapa yang mau dikirimi notifikasi)
  static Future<List<Map<String, dynamic>>> getOtherUsersWithTokens() async {
    final currentUserId = _supabase.auth.currentUser?.id;

    final response = await _supabase
        .from('fcm_tokens')
        .select('user_id, token, updated_at')
        .neq('user_id', currentUserId ?? '');

    // Kelompokkan token berdasarkan user_id
    final Map<String, List<String>> userTokens = {};
    for (final row in response as List) {
      final uid = row['user_id'] as String;
      final token = row['token'] as String;
      if (!userTokens.containsKey(uid)) {
        userTokens[uid] = [];
      }
      userTokens[uid]!.add(token);
    }

    final List<Map<String, dynamic>> users = [];
    userTokens.forEach((uid, tokens) {
      users.add({
        'user_id': uid,
        'tokens': tokens,
        'display': 'User ${uid.substring(0, 8)} (${tokens.length} Perangkat)',
      });
    });

    return users;
  }

  /// Kirim notifikasi ke beberapa target user sekaligus
  static Future<bool> sendNotificationToUsers({
    required List<String> targetUserIds,
    required String title,
    required String body,
  }) async {
    try {
      if (targetUserIds.isEmpty) {
        debugPrint('[Notif] Error: Target user list kosong');
        return false;
      }

      // Ambil semua token untuk semua target user
      final response = await _supabase
          .from('fcm_tokens')
          .select('token')
          .inFilter('user_id', targetUserIds);

      final List<String> targetTokens = (response as List)
          .map((row) => row['token'] as String)
          .where((t) => t.trim().isNotEmpty)
          .toList();

      if (targetTokens.isEmpty) {
        debugPrint('[Notif] Error: Target user tidak memiliki token aktif');
        return false;
      }

      final senderName =
          _supabase.auth.currentUser?.userMetadata?['full_name'] ?? 'Seseorang';

      // Panggil Supabase Edge Function
      final result = await _supabase.functions.invoke(
        'send-notification',
        body: {
          'targetTokens': targetTokens,
          'title': title,
          'body': body,
          'senderName': senderName,
        },
      );

      debugPrint('[Notif] Berhasil dikirim ke ${targetTokens.length} perangkat. Response: ${result.data}');
      return true;
    } on FunctionException catch (e) {
      debugPrint('[Notif] Function Error: $e');
      return false;
    } catch (e) {
      debugPrint('[Notif] Error: $e');
      return false;
    }
  }

  /// Kirim notifikasi ke SATU user tertentu (tetap dipertahankan untuk backward compatibility)
  static Future<bool> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
  }) async {
    return sendNotificationToUsers(
      targetUserIds: [targetUserId],
      title: title,
      body: body,
    );
  }
}
