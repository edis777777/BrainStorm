import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_models.dart';
import '../state/app_providers.dart';
import 'home_screen.dart';
import 'lobby_screen.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String userId;
  final String playerName;
  final bool isHost;
  final String roomCode;

  const LeaderboardScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.playerName,
    required this.isHost,
    required this.roomCode,
  });

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<RoomPlayerModel> playersFinished = [];
  bool allPlayersFinished = false;

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
            roomCode: widget.roomCode,
          ),
        ),
      );
    });

    playersSub = supabase.playerRowsStream(roomId: widget.roomId).listen((rows) {
      if (!mounted) return;
      final allPlayers = rows.map((e) => RoomPlayerModel.fromJson(e)).toList();
      final allFinished = allPlayers.every((p) => p.finished);
      setState(() {
        playersFinished = _rankedFinished(rows);
        allPlayersFinished = allFinished;
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
        title: const Text('Rezultatai'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!allPlayersFinished)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Text(
                  'Jūs baigėte! Laukiama, kol kiti žaidėjai baigs viktoriną...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            if (!allPlayersFinished)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Baigusių žaidėjų rezultatai',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: playersFinished.isEmpty
                  ? const Center(child: Text('Laukiama rezultatų...'))
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
                '$rank.',
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
                onPressed: widget.isHost && allPlayersFinished
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
                              roomCode: widget.roomCode,
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text('Žaisti dar kartą'),
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
                child: const Text('Baigti'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
