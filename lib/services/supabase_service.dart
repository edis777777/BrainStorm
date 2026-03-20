import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart' show PostgresChangeFilter, PostgresChangeFilterType;

import '../config.dart';
import '../models/quiz_question.dart';

class SupabaseService {
  final SupabaseClient client;

  SupabaseService._(this.client);

  static SupabaseService create() {
    AppConfig.assertSupabaseConfigured();
    final url = AppConfig.supabaseUrl;
    final anonKey = AppConfig.supabaseAnonKey;
    final client = SupabaseClient(url, anonKey);
    return SupabaseService._(client);
  }

  Future<String> signInAnonymously() async {
    final auth = client.auth;
    final currentSession = auth.currentSession;
    if (currentSession?.user != null) {
      return currentSession!.user!.id;
    }

    final res = await auth.signInAnonymously();
    return res.user!.id;
  }

  Future<String> createRoom({
    required String hostUserId,
    required String code,
    required int gameSeed,
  }) async {
    final inserted = await client
        .from('rooms')
        .insert({
          'code': code,
          'host_user_id': hostUserId,
          'game_started': false,
          'game_seed': gameSeed,
        })
        .select()
        .single();
    return inserted['id'].toString();
  }

  Future<Map<String, dynamic>?> getRoomByCode(String code) async {
    final rows = await client.from('rooms').select().eq('code', code).limit(1);
    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }

  Future<String> addPlayerToRoom({
    required String roomId,
    required String userId,
    required String playerName,
  }) async {
    await client.from('room_players').upsert({
      'room_id': roomId,
      'user_id': userId,
      'player_name': playerName,
      'ready': false,
      'started': false,
      'finished': false,
      'correct_count': 0,
      'total_time_ms': null,
    }, onConflict: 'room_id,user_id');
    return roomId;
  }

  Future<Map<String, dynamic>?> getPlayerInRoom({
    required String roomId,
    required String userId,
  }) async {
    final rows = await client
        .from('room_players')
        .select()
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }

  Stream<List<Map<String, dynamic>>> playerRowsStream({
    required String roomId,
    List<Map<String, dynamic>> initialPlayers = const [],
  }) {
    // Consumers should call initial fetch separately; this stream just pushes updates.
    final controller = StreamController<List<Map<String, dynamic>>>();
    final players = List<Map<String, dynamic>>.from(initialPlayers);

    void emit() {
      controller.add(List<Map<String, dynamic>>.from(players));
    }

    final channel = client.channel('players_stream_$roomId');

    // Helper for updating local cache
    void upsertRow(Map<String, dynamic> row) {
      final userId = row['user_id']?.toString();
      final idx = players.indexWhere((e) => e['user_id']?.toString() == userId);
      if (idx >= 0) {
        players[idx] = row;
      } else {
        players.add(row);
      }
    }

    void removeRow(Map<String, dynamic> row) {
      final userId = row['user_id']?.toString();
      players.removeWhere((e) => e['user_id']?.toString() == userId);
    }

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'room_players',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        final newRow = payload.newRecord as Map<String, dynamic>;
        upsertRow(newRow);
        emit();
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'room_players',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        final newRow = payload.newRecord as Map<String, dynamic>;
        upsertRow(newRow);
        emit();
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'room_players',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'room_id',
        value: roomId,
      ),
      callback: (payload) {
        final oldRow = payload.oldRecord as Map<String, dynamic>;
        removeRow(oldRow);
        emit();
      },
    );

    channel.subscribe();
    if (initialPlayers.isNotEmpty) {
      // Emit immediately so the UI can render before the first realtime event.
      emit();
    }

    controller.onCancel = () async {
      await client.removeChannel(channel);
      await controller.close();
    };

    return controller.stream;
  }

  Stream<Map<String, dynamic>> roomRowStream({
    required String roomId,
    Map<String, dynamic>? initialRoom,
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    final channel = client.channel('room_stream_$roomId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'rooms',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: roomId,
      ),
      callback: (payload) {
        controller.add(payload.newRecord as Map<String, dynamic>);
      },
    );

    channel.subscribe();

    if (initialRoom != null) {
      controller.add(Map<String, dynamic>.from(initialRoom));
    }

    controller.onCancel = () async {
      await client.removeChannel(channel);
      await controller.close();
    };

    return controller.stream;
  }

  Future<Map<String, dynamic>> fetchRoom({required String roomId}) async {
    final rows = await client.from('rooms').select().eq('id', roomId).limit(1);
    if (rows.isEmpty) {
      throw StateError('Room not found: $roomId');
    }
    return rows.first as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchPlayers({required String roomId}) async {
    final rows = await client
        .from('room_players')
        .select()
        .eq('room_id', roomId);
    return rows.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<void> setReady({required String roomId, required String userId, required bool ready}) async {
    await client.from('room_players').update({'ready': ready}).eq('room_id', roomId).eq('user_id', userId);
  }

  Future<void> markStarted({required String roomId, required String userId}) async {
    await client.from('room_players').update({'started': true}).eq('room_id', roomId).eq('user_id', userId);
  }

  Future<void> submitResult({
    required String roomId,
    required String userId,
    required int correctCount,
    required int totalTimeMs,
  }) async {
    await client.from('room_players').update({
      'finished': true,
      'correct_count': correctCount,
      'total_time_ms': totalTimeMs,
    }).eq('room_id', roomId).eq('user_id', userId);
  }

  Future<void> hostStartGame({
    required String roomId,
    required int gameSeed,
  }) async {
    await client.from('rooms').update({
      'game_started': true,
      'game_seed': gameSeed,
    }).eq('id', roomId);
  }

  Future<void> hostResetRound({
    required String roomId,
    required int nextGameSeed,
  }) async {
    // Host resets the round and clears player flags.
    await client.from('rooms').update({
      'game_started': false,
      'game_seed': nextGameSeed,
    }).eq('id', roomId);

    await client.from('room_players').update({
      'ready': false,
      'started': false,
      'finished': false,
      'correct_count': 0,
      'total_time_ms': null,
    }).eq('room_id', roomId);
  }

  Future<void> leaveRoom({required String roomId, required String userId}) async {
    await client.from('room_players').delete().eq('room_id', roomId).eq('user_id', userId);
  }

  Future<List<QuizQuestion>> fetchQuestions({
    required int seed,
    int limit = 10,
  }) async {
    // Expects public.get_questions(p_seed bigint, p_limit int) returning setof questions.
    final result = await client.rpc(
      'get_questions',
      params: <String, dynamic>{
        'p_seed': seed,
        'p_limit': limit,
      },
    );

    final rows = switch (result) {
      final List<dynamic> list => list,
      final Map<dynamic, dynamic> map => (map['data'] as List<dynamic>? ?? const []),
      _ => const <dynamic>[],
    };

    if (rows.isEmpty) {
      return const <QuizQuestion>[];
    }

    final mapped = rows.cast<Map<String, dynamic>>().map((row) => QuizQuestion.fromSupabaseRow(row)).toList();
    return mapped;
  }
}

