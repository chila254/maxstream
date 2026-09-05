/// Supabase configuration for full cloud sync (free tier).
/// Create a project at https://supabase.com -> Settings -> API -> copy URL + anon key.
/// For local dev you can leave these empty and CloudSyncService (Firebase RTDB) will remain active.
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_ANON_KEY',
  );

  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR_PROJECT') && !supabaseAnonKey.contains('YOUR_ANON_KEY');
}
