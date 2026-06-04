// lib/screens/notification_screen.dart
// Kirim push notif ke perangkat B tapi TIDAK ke C

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController(text: 'Halo dari PBM App!');
  final _bodyController = TextEditingController(
    text: 'Ini notifikasi khusus untukmu 👋',
  );

  List<Map<String, dynamic>> _users = [];
  final Set<String> _selectedUserIds = {};
  bool _isSending = false;
  bool _isLoadingUsers = true;
  String? _myFCMToken;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadMyToken();
  }

  Future<void> _loadUsers() async {
    final users = await NotificationService.getOtherUsersWithTokens();
    setState(() {
      _users = users;
      _isLoadingUsers = false;
    });
  }

  Future<void> _loadMyToken() async {
    final currentUserId = AuthService.currentUser?.id;
    if (currentUserId == null) return;

    final data = await _supabase
        .from('fcm_tokens')
        .select('token')
        .eq('user_id', currentUserId)
        .maybeSingle();

    setState(() {
      _myFCMToken = data?['token'] as String?;
    });
  }

  Future<void> _sendNotification() async {
    if (_selectedUserIds.isEmpty) {
      _showSnack('Pilih dulu penerima notifikasi!', isError: true);
      return;
    }

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showSnack('Judul dan isi tidak boleh kosong', isError: true);
      return;
    }

    setState(() => _isSending = true);
    final success = await NotificationService.sendNotificationToUsers(
      targetUserIds: _selectedUserIds.toList(),
      title: title,
      body: body,
    );
    setState(() => _isSending = false);

    if (success) {
      _showSnack('✅ Notifikasi berhasil dikirim!');
    } else {
      _showSnack('❌ Gagal mengirim notifikasi', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info penjelasan
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4F46E5).withAlpha(51)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF4F46E5),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Cara Kerja Push Notifikasi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Pilih 1 user target (Perangkat B)\n'
                  '• Klik Kirim → notifikasi hanya masuk ke Perangkat B\n'
                  '• Perangkat C yang tidak dipilih TIDAK menerima notifikasi',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Token saya
          const Text(
            'FCM Token Perangkat Ini',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _myFCMToken ?? 'Loading token...',
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 24),

          // Pilih penerima
          const Text(
            'Pilih Penerima Notifikasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),

          if (_isLoadingUsers)
            const Center(child: CircularProgressIndicator())
          else if (_users.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Belum ada user lain yang online.\nLogin dari perangkat lain dulu!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _users.map((user) {
                final userId = user['user_id'] as String;
                final shortId = userId.substring(0, 12);
                final isSelected = _selectedUserIds.contains(userId);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedUserIds.remove(userId);
                      } else {
                        _selectedUserIds.add(userId);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4F46E5)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4F46E5)
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isSelected
                              ? Colors.white24
                              : const Color(0xFF4F46E5).withAlpha(26),
                          child: Icon(
                            Icons.phone_android,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF4F46E5),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['display'] as String? ?? 'Perangkat / User',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'ID: $shortId...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.white),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Judul notifikasi
          const Text(
            'Judul Notifikasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Judul notifikasi...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixIcon: const Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 16),

          // Isi notifikasi
          const Text(
            'Isi Notifikasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tulis pesan notifikasi...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              prefixIcon: const Icon(Icons.message),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 28),

          // Tombol kirim
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendNotification,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSending ? 'Mengirim...' : 'Kirim ke Perangkat Terpilih',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              'Hanya perangkat yang dipilih yang menerima notifikasi',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
