// lib/models/message_model.dart

/// Model data untuk pesan chat
class MessageModel {
  /// ID unik pesan
  final String id;

  /// ID ruangan chat (default: 'general')
  final String roomId;

  /// ID user pengirim
  final String userId;

  /// Isi pesan
  final String content;

  /// Waktu pesan dibuat
  final DateTime createdAt;

  /// Nama pengirim (dari auth metadata)
  final String senderName;

  MessageModel({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.senderName,
  });

  /// Factory constructor untuk membuat MessageModel dari JSON (Supabase response)
  factory MessageModel.fromJson(Map<String, dynamic> json, String senderName) {
    return MessageModel(
      id: json['id'] as String,
      roomId: json['room_id'] as String? ?? 'general',
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderName: senderName,
    );
  }

  /// Convert MessageModel ke JSON untuk Supabase
  Map<String, dynamic> toJson() {
    return {'room_id': roomId, 'user_id': userId, 'content': content};
  }

  /// Buat copy dengan field yang berbeda
  MessageModel copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? content,
    DateTime? createdAt,
    String? senderName,
  }) {
    return MessageModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
    );
  }

  @override
  String toString() =>
      'MessageModel(id: $id, roomId: $roomId, userId: $userId, senderName: $senderName, content: $content, createdAt: $createdAt)';
}
