class SupabaseConfig {
  static const String _placeholderAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrdnJtY2F6dnFyd2x6cnRpZ2JrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0ODczODYsImV4cCI6MjA5MzA2MzM4Nn0.FBqaJDh_FoMk8PJDsiV92FgIvZ7-F5iHYa3PS2Bd6fA';

  static const String url = 'https://vkvrmcazvqrwlzrtigbk.supabase.co';

  static const String anonKey =
      'sb_publishable_hHHzku71fkpjNz7xs6T4TQ_4b_eZs3O';

  static bool get isConfigured {
    final normalizedUrl = url.trim();
    final normalizedAnonKey = anonKey.trim();
    return normalizedUrl.startsWith('https://') &&
        normalizedAnonKey.isNotEmpty &&
        normalizedAnonKey != _placeholderAnonKey;
  }
}
