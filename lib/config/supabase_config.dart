/// Supabase configuration for full cloud sync (free tier).
/// Create a project at https://supabase.com -> Settings -> API -> copy URL + anon key.
/// For local dev you can leave these empty and CloudSyncService (Firebase RTDB) will remain active.
class SupabaseConfig {
  // Defaults to your project so local `flutter run` works without --dart-define.
  // CI uses GitHub Secrets SUPABASE_URL / SUPABASE_ANON_KEY (or PUBLISHABLE) via --dart-define.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lzfiqrodslkzirbbyfcw.supabase.co',
  );
  // Use the `anon public` JWT (ey...) if you have it, or the new `publishable` (sb_publishable_...)
  // Both work with supabase_flutter 2.8+; publishable is the new default in dashboard.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_6mF34lxnGvsJ7OmcyZffYQ_PaKitixG',
  );

  static bool get isConfigured =>
      supabaseUrl.contains('supabase.co') && supabaseAnonKey.isNotEmpty && !supabaseAnonKey.contains('YOUR_ANON');
}
