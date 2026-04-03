import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

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
      return currentSession!.user.id;
    }

    final res = await auth.signInAnonymously();
    return res.user!.id;
  }

  Future<Map<String, dynamic>> createRoom({
    required String hostUserId,
    required int gameSeed,
  }) async {
    final r = Random();
    const maxAttempts = 10;
    for (var i = 0; i < maxAttempts; i++) {
      final code = (1000 + r.nextInt(9000)).toString();
      try {
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
        return inserted;
      } on PostgrestException catch (e) {
        if (e.code == '23505') { // unique_violation for PostgreSQL
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Failed to generate a unique room code.');
  }

  Future<Map<String, dynamic>?> getRoomByCode(String code) async {
    final rows = await client.from('rooms').select().eq('code', code).limit(1);
    if (rows.isEmpty) return null;
    return rows.first;
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
    return rows.first;
  }

  Stream<List<Map<String, dynamic>>> playerRowsStream({required String roomId}) {
    // The stream() method handles fetching the initial data and listening for changes.
    return client
        .from('room_players')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('room_id', roomId)
        .order('player_name', ascending: true);
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
        controller.add(payload.newRecord);
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
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> fetchPlayers({required String roomId}) async {
    final rows = await client
        .from('room_players')
        .select()
        .eq('room_id', roomId);
    return rows.map((e) => e).toList();
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
    const categories = [
      'Gamta', 'Geografija', 'Istorija', 'Sportas', 'Mokslas', 'Menai', 'Lietuva', 'Bendras', 'Bendras', 'Bendras'
    ];
    final List<int> currentQuestionIds = [];
    final Set<int> usedIds = {};

    for (final category in categories) {
      int? qId = await _fetchSingleRoomCategoryQuestion(roomId, category, usedIds);

      // Fallback
      if (qId == null && category != 'Bendras') {
        qId = await _fetchSingleRoomCategoryQuestion(roomId, 'Bendras', usedIds);
      }

      if (qId != null) {
        currentQuestionIds.add(qId);
        usedIds.add(qId);
      }
    }

    await client.from('rooms').update({
      'game_started': true,
      'game_seed': gameSeed,
      'current_question_ids': currentQuestionIds,
    }).eq('id', roomId);
  }

  Future<int?> _fetchSingleRoomCategoryQuestion(String roomId, String category, Set<int> usedIds) async {
    final result = await client.rpc(
      'get_unplayed_room_questions_by_category',
      params: <String, dynamic>{
        'p_room_id': roomId,
        'p_category': category,
        'p_limit': 15, // Paimame daugiau, kad atfiltruotume jau panaudotus, net jei reikia 1
      },
    );
    final rows = result as List<dynamic>? ?? [];
    for (var row in rows) {
      final id = int.parse(row['id'].toString());
      if (!usedIds.contains(id)) {
        return id;
      }
    }
    return null;
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
    String? userId,
    int limit = 10,
  }) async {
    const categories = [
      'Gamta', 'Geografija', 'Istorija', 'Sportas', 'Mokslas', 'Menai', 'Lietuva', 'Bendras', 'Bendras', 'Bendras'
    ];
    final List<QuizQuestion> finalQuestions = [];
    final Set<int> usedIds = {};

    for (final category in categories) {
      QuizQuestion? question = await _fetchSingleCategoryQuestion(userId, category, usedIds);

      // Fallback
      if (question == null && category != 'Bendras') {
        question = await _fetchSingleCategoryQuestion(userId, 'Bendras', usedIds);
      }

      if (question != null) {
        finalQuestions.add(question);
        usedIds.add(question.id);
      }
    }

    return finalQuestions;
  }

  Future<QuizQuestion?> _fetchSingleCategoryQuestion(String? userId, String category, Set<int> usedIds) async {
    final result = await client.rpc(
      'get_unplayed_questions_by_category',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_category': category,
        'p_limit': 15, // Paimame daugiau, kad atfiltruotume jau panaudotus, net jei reikia 1
      },
    );

    final rows = switch (result) {
      final List<dynamic> list => list,
      final Map<dynamic, dynamic> map => (map['data'] as List<dynamic>? ?? const []),
      _ => const <dynamic>[],
    };

    for (var row in rows) {
      final q = QuizQuestion.fromSupabaseRow(row as Map<String, dynamic>);
      if (!usedIds.contains(q.id)) {
        return q;
      }
    }
    return null;
  }

  Future<List<QuizQuestion>> fetchQuestionsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    
    final rows = await client
        .from('questions')
        .select()
        .inFilter('id', ids);
        
    final mapped = rows.map((row) => QuizQuestion.fromSupabaseRow(row)).toList();
    
    // Sort to maintain EXACTly the same sequence as in the ids list
    mapped.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    
    return mapped;
  }

  Future<void> recordPlayedQuestions({
    required String userId,
    required List<int> questionIds,
  }) async {
    if (questionIds.isEmpty) {
      return;
    }
    final records = questionIds
        .map((qid) => {
              'user_id': userId,
              'question_id': qid,
              'played_at': DateTime.now().toUtc().toIso8601String(),
            })
        .toList();

    await client.from('played_questions').insert(records);
  }
}
