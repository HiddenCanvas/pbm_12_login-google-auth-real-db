// lib/services/auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static final _googleSignIn = GoogleSignIn(
    clientId: AppConfig.googleWebClientId,
    scopes: ['email', 'profile'],
  );

  /// Login dengan Google → Supabase
  static Future<AuthResponse?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('[Auth] User membatalkan login');
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw Exception('Google ID Token kosong');

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('[Auth] Login berhasil: ${response.user?.email}');
      return response;
    } catch (e) {
      debugPrint('[Auth] Error: $e');
      rethrow;
    }
  }

  /// Logout dari Google dan Supabase
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
    debugPrint('[Auth] Logout berhasil');
  }

  /// User yang sedang login
  static User? get currentUser => _supabase.auth.currentUser;

  /// Nama display user
  static String get displayName =>
      currentUser?.userMetadata?['full_name'] ??
      currentUser?.email ??
      'Unknown';

  /// Avatar URL user
  static String? get avatarUrl =>
      currentUser?.userMetadata?['avatar_url'] as String?;

  /// Stream perubahan status auth
  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;
}
