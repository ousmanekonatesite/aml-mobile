import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
  static String get configurationMessage => isConfigured
      ? 'Supabase est configuré.'
      : 'Supabase n’est pas configuré dans cet APK. Vérifie les secrets GitHub SUPABASE_URL et SUPABASE_ANON_KEY, puis reconstruis l’application.';

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: url.trim(), anonKey: anonKey.trim());
  }

  static SupabaseClient? get client => isConfigured ? Supabase.instance.client : null;
}
