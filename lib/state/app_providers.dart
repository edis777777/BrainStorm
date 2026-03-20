import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService.create();
});

final authUserIdProvider = FutureProvider<String>((ref) async {
  final supabase = ref.read(supabaseServiceProvider);
  return supabase.signInAnonymously();
});

final playerNameProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('player_name');
});

final localPlayerNameProvider = StateProvider<String?>((ref) => null);

Future<void> savePlayerName(String name) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('player_name', name);
}

