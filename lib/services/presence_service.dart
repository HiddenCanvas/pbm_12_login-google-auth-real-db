// lib/services/presence_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  static final _supabase = Supabase.instance.client;
  static RealtimeChannel? _presenceChannel;
  
  // ValueNotifier agar UI bisa mendengarkan perubahan daftar user online secara otomatis
  static final ValueNotifier<Map<String, Map<String, dynamic>>> onlineUsers = 
      ValueNotifier({});

  /// Mulai melacak status online perangkat ini dan mendengarkan status perangkat lain
  static void initialize() {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;

    // Bersihkan channel jika sudah ada sebelumnya
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
    }

    _presenceChannel = _supabase.channel('online-devices', opts: const RealtimeChannelConfig(self: true));

    _presenceChannel!.onPresenceSync((payload) {
      final state = _presenceChannel!.presenceState();
      
      final Map<String, Map<String, dynamic>> onlineMap = {};
      for (final singlePresence in state) {
        for (final presence in singlePresence.presences) {
          final userId = presence.payload['user_id'] as String?;
          if (userId != null) {
            onlineMap[userId] = Map<String, dynamic>.from(presence.payload);
          }
        }
      }
      
      onlineUsers.value = onlineMap;
      debugPrint('[Presence] Sync: ${onlineUsers.value.keys.toList()}');
    }).onPresenceJoin((payload) {
      debugPrint('[Presence] Join: ${payload.newPresences}');
    }).onPresenceLeave((payload) {
      debugPrint('[Presence] Leave: ${payload.leftPresences}');
    });

    _presenceChannel!.subscribe((status, response) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Kirim payload kehadiran (presence info) ke channel
        await _presenceChannel!.track({
          'user_id': currentUser.id,
          'online_at': DateTime.now().toIso8601String(),
          'full_name': currentUser.userMetadata?['full_name'] ?? 'User',
        });
        debugPrint('[Presence] Melacak status online user: ${currentUser.id}');
      }
    });
  }

  /// Periksa apakah user tertentu sedang online
  static bool isUserOnline(String userId) {
    return onlineUsers.value.containsKey(userId);
  }

  /// Berhenti melacak status online (misal saat logout)
  static void dispose() {
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
      _presenceChannel = null;
    }
    onlineUsers.value = {};
  }
}
