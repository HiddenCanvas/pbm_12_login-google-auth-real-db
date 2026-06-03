// lib/config/app_config.dart

class AppConfig {
  // ─── Supabase ───────────────────────────────────────────────
  static const String supabaseUrl = 'https://gxwvurwxoexpfnmchhvi.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4d3Z1cnd4b2V4cGZubWNoaHZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA0ODA3NjgsImV4cCI6MjA5NjA1Njc2OH0.qzffssVwq9zwIeuWchXVCqnqUB-1pTnaCxMrM2_O-rI';

  // ─── Firebase ────────────────────────────────────────────────
  static const String firebaseProjectId = 'mapia-9b430';
  static const String firebaseAppId =
      '1:454223343843:android:3f82b173b4fbf953c695d6';

  // ─── Google Sign In ──────────────────────────────────────────
  // Isi dengan Web Client ID dari Google Cloud Console
  // Project: mapia-9b430 → APIs & Services → Credentials → OAuth 2.0
  static const String googleWebClientId =
      'https://gxwvurwxoexpfnmchhvi.supabase.co/auth/v1/callback';
}