import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_models.dart';
import '../services/supabase_service.dart';
import '../state/app_providers.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String userId;
  final String playerName;
  final bool isHost;

  const LeaderboardScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.playerName,
    required this.isHost,
  });

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<RoomPlayerModel> playersFinished = [];

  StreamSubscription? playersSub;
  StreamSubscription? roomSub;
  bool didNavigateBackToLobby = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    playersSub?.cancel();
    roomSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final supabase = ref.read(supabaseServiceProvider);
    final initialRoom = await supabase.fetchRoom(roomId: widget.roomId);
    final initialPlayers = await supabase.fetchPlayers(roomId: widget.roomId);

    setState(() {
      playersFinished = _rankedFinished(initialPlayers);
    });

    roomSub = supabase
        .roomRowStream(roomId: widget.roomId, initialRoom: initialRoom)
        .listen((newRoom) {
      final gameStarted = (newRoom['game_started'] as bool?) ?? false;
      if (gameStarted) return;

      if (didNavigateBackToLobby) return;
      didNavigateBackToLobby = true;

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomId: widget.roomId,
            userId: widget.userId,
            playerName: widget.playerName,
            isHost: widget.isHost,
          ),
        ),
      );
    });

    playersSub = supabase
        .playerRowsStream(
          roomId: widget.roomId,
          initialPlayers: initialPlayers,
        )
        .listen((rows) {
      if (!mounted) return;
      setState(() {
        playersFinished = _rankedFinished(rows);
      });
    });
  }

  List<RoomPlayerModel> _rankedFinished(List<Map<String, dynamic>> rows) {
    final all = rows
        .map((e) => RoomPlayerModel.fromJson(e))
        // Only show players who actually finished and have timing data.
        .where((p) => p.finished && p.totalTimeMs != null && p.playerName.trim().isNotEmpty)
        .toList();
    all.sort((a, b) {
      // Primary: most correct answers
      final correctCmp = b.correctCount.compareTo(a.correctCount);
      if (correctCmp != 0) return correctCmp;

      // Secondary: shortest total time
      return a.totalTimeMs!.compareTo(b.totalTimeMs!);
    });
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Live Rankings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: playersFinished.isEmpty
                  ? const Center(child: Text('Waiting for other players...'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: playersFinished.length,
                      itemBuilder: (context, index) {
                        final p = playersFinished[index];
                        final rank = index + 1;
                        final ms = p.totalTimeMs ?? 0;
                        final secs = ms / 1000.0;
                        return _rankRow(rank: rank, p: p, secs: secs);
                      },
                    ),
            ),
            _bottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _rankRow({
    required int rank,
    required RoomPlayerModel p,
    required double secs,
  }) {
    return Card(
      color: rank == 1 ? Colors.amber.withOpacity(0.2) : Colors.white10,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                '#$rank',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            Expanded(
              child: Text(
                rank == 1 ? '🏆 ${p.playerName}' : p.playerName,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${p.correctCount} / 10',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            Text(
              '${secs.toStringAsFixed(1)}s',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions() {
    final supabase = ref.read(supabaseServiceProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.isHost
                    ? () async {
                        didNavigateBackToLobby = true;
                        // Start next round: clear everyone back to Lobby state.
                        final seed = DateTime.now().millisecondsSinceEpoch;
                        await supabase.hostResetRound(
                          roomId: widget.roomId,
                          nextGameSeed: seed,
                        );
                        if (!mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => LobbyScreen(
                              roomId: widget.roomId,
                              userId: widget.userId,
                              playerName: widget.playerName,
                              isHost: true,
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text('Next Game'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await supabase.leaveRoom(roomId: widget.roomId, userId: widget.userId);
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => HomeScreen(playerName: widget.playerName),
                    ),
                  );
                },
                child: const Text('Finish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

