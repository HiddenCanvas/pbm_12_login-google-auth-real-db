// lib/services/chat_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import 'auth_service.dart';

/// Service untuk operasi chat realtime
class ChatService {
  static final _supabase = Supabase.instance.client;

  /// Default room ID
  static const String defaultRoom = 'general';

  /// Kirim pesan ke room chat
  ///
  /// Parameter:
  /// - [content]: Isi pesan
  /// - [roomId]: ID room (default: 'general')
  static Future<bool> sendMessage(
    String content, {
    String roomId = defaultRoom,
  }) async {
    try {
      // Validasi input
      if (content.trim().isEmpty) {
        debugPrint('[Chat] Error: Pesan tidak boleh kosong');
        return false;
      }

      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        debugPrint('[Chat] Error: User tidak login');
        return false;
      }

      // Insert pesan ke Supabase
      await _supabase.from('messages').insert({
        'room_id': roomId,
        'user_id': currentUser.id,
        'content': content.trim(),
      });

      debugPrint('[Chat] Pesan terkirim ke $roomId');
      return true;
    } catch (e) {
      debugPrint('[Chat] Error sending message: $e');
      return false;
    }
  }

  // Dapatkan stream pesan realtime dari room
  // Menggunakan Supabase Realtime untuk live updates
  // Parameter:
  // - roomId: ID room (default: 'general')
  // Returns: Stream<List<MessageModel>> yang realtime
  static Stream<List<MessageModel>> getMessageStream({
    String roomId = defaultRoom,
  }) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((rawMessages) {
          // Convert dari JSON ke MessageModel dengan senderName
          return rawMessages.map((raw) async {
            // Ambil sender name dari auth metadata
            try {
              final senderData = await _supabase.auth.admin.getUserById(
                raw['user_id'],
              );
              final senderName =
                  senderData.user?.userMetadata?['full_name']?.toString() ??
                  raw['user_id'].toString().substring(0, 8);
              return MessageModel.fromJson(
                Map<String, dynamic>.from(raw as Map),
                senderName,
              );
            } catch (e) {
              // Fallback jika gagal ambil metadata
              final fallbackName = raw['user_id'].toString().substring(0, 8);
              return MessageModel.fromJson(
                Map<String, dynamic>.from(raw as Map),
                fallbackName,
              );
            }
          }).toList();
        })
        .asyncMap((futures) async {
          // Resolve semua futures
          return await Future.wait(futures);
        })
        .handleError((error) {
          debugPrint('[Chat] Stream error: $error');
        });
  }

  /// Hapus pesan (hanya user pengirim yang bisa)
  ///
  /// Parameter:
  /// - [messageId]: ID pesan yang akan dihapus
  static Future<bool> deleteMessage(String messageId) async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        debugPrint('[Chat] Error: User tidak login');
        return false;
      }

      // Cek apakah user adalah pengirim pesan
      final message = await _supabase
          .from('messages')
          .select()
          .eq('id', messageId)
          .maybeSingle();

      if (message == null) {
        debugPrint('[Chat] Error: Pesan tidak ditemukan');
        return false;
      }

      if (message['user_id'] != currentUser.id) {
        debugPrint('[Chat] Error: Hanya pengirim yang bisa hapus pesan');
        return false;
      }

      // Hapus pesan
      await _supabase.from('messages').delete().eq('id', messageId);

      debugPrint('[Chat] Pesan dihapus: $messageId');
      return true;
    } catch (e) {
      debugPrint('[Chat] Error deleting message: $e');
      return false;
    }
  }

  /// Update pesan (hanya user pengirim yang bisa)
  ///
  /// Parameter:
  /// - [messageId]: ID pesan
  /// - [newContent]: Konten pesan yang baru
  static Future<bool> updateMessage(String messageId, String newContent) async {
    try {
      // Validasi
      if (newContent.trim().isEmpty) {
        debugPrint('[Chat] Error: Konten tidak boleh kosong');
        return false;
      }

      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        debugPrint('[Chat] Error: User tidak login');
        return false;
      }

      // Cek apakah user adalah pengirim pesan
      final message = await _supabase
          .from('messages')
          .select()
          .eq('id', messageId)
          .maybeSingle();

      if (message == null) {
        debugPrint('[Chat] Error: Pesan tidak ditemukan');
        return false;
      }

      if (message['user_id'] != currentUser.id) {
        debugPrint('[Chat] Error: Hanya pengirim yang bisa edit pesan');
        return false;
      }

      // Update pesan
      await _supabase
          .from('messages')
          .update({'content': newContent.trim()})
          .eq('id', messageId);

      debugPrint('[Chat] Pesan diupdate: $messageId');
      return true;
    } catch (e) {
      debugPrint('[Chat] Error updating message: $e');
      return false;
    }
  }

  /// Dapatkan jumlah pesan di room
  static Future<int> getMessageCount({String roomId = defaultRoom}) async {
    try {
      final count = await _supabase
          .from('messages')
          .count(CountOption.exact)
          .eq('room_id', roomId);

      return count;
    } catch (e) {
      debugPrint('[Chat] Error getting message count: $e');
      return 0;
    }
  }
}
