class AppConfig {
  // Provide these via --dart-define when running:
  // flutter run --dart-define=SUPABASE_URL="https://xxxx.supabase.co" --dart-define=SUPABASE_ANON_KEY="..."
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://arjcfftxmhryvbrujnyj.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_sKJszrRzVMKObnuWcJvfvQ_kYiomLpt',
  );

  static void assertSupabaseConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase is not configured. Run with --dart-define=SUPABASE_URL and --dart-define=SUPABASE_ANON_KEY.',
      );
    }
  }
}

