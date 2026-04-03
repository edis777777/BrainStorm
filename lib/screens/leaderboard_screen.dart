import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_models.dart';
import '../state/app_providers.dart';
import '../services/audio_service.dart';
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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollPlayers());
  }

  Future<void> _pollPlayers() async {
    if (allPlayersFinished || didNavigateBackToLobby) return;
    try {
      final rows = await ref.read(supabaseServiceProvider).fetchPlayers(roomId: widget.roomId);
      if (!mounted) return;
      final allPlayers = rows.map((e) => RoomPlayerModel.fromJson(e)).toList();
      final allFinished = allPlayers.every((p) => p.finished);
      final bool wasFinished = allPlayersFinished;
      // Merge logic or overwrite. Overwriting is safe since fetch is fresh from DB.
      setState(() {
        playersFinished = _rankedFinished(rows);
        allPlayersFinished = allFinished;
      });

      if (!wasFinished && allFinished) {
        _checkAndPlayChampion();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
      final bool wasFinished = allPlayersFinished;
      setState(() {
        playersFinished = _rankedFinished(rows);
        allPlayersFinished = allFinished;
      });

      if (!wasFinished && allFinished) {
        _checkAndPlayChampion();
      }
    });
  }

  void _checkAndPlayChampion() {
    int myRank = -1;
    for (int i = 0; i < playersFinished.length; i++) {
      if (playersFinished[i].userId == widget.userId) {
        myRank = i + 1;
        break;
      }
    }
    if (myRank == 1) {
      audioService.playChampionSound();
    }
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
    int myRank = -1;
    for (int i = 0; i < playersFinished.length; i++) {
      if (playersFinished[i].userId == widget.userId) {
        myRank = i + 1;
        break;
      }
    }
    final mascotImage = (myRank == 1) ? 'assets/saunuolis.png' : 'assets/nenusimink.png';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Rezultatai', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/fonas.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.4)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(
                    allPlayersFinished
                        ? 'SVEIKINAME ŠIO ŽAIDIMO NUGALĖTOJĄ, BANDYKITE DAR KARTĄ'
                        : 'PALAUKIME, KOL VISI ŽAIDĖJAI ATSAKYS Į KLAUSIMUS.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                  child: playersFinished.isEmpty
                      ? const Center(child: Text('Laukiama rezultatų...', style: TextStyle(color: Colors.white)))
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
                const SizedBox(height: 16),
                Expanded(
                  child: Image.asset(mascotImage, fit: BoxFit.contain),
                ),
                _bottomActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankRow({
    required int rank,
    required RoomPlayerModel p,
    required double secs,
  }) {
    Color bgColor;
    Color textColor = Colors.black;
    if (rank == 1) {
      bgColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2) {
      bgColor = const Color(0xFFEEEEEE); // Lighter Silver
    } else if (rank == 3) {
      bgColor = const Color(0xFFCD7F32); // Bronze
    } else {
      bgColor = Colors.grey.shade800;
      textColor = Colors.white; // Better contrast
    }

    final formattedSecs = secs.toStringAsFixed(1).replaceAll('.', ',');

    return Card(
      color: bgColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank.',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
              ),
            ),
            Expanded(
              child: Text(
                p.playerName,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
              ),
            ),
            Text(
              '${p.correctCount}/10',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor),
            ),
            const SizedBox(width: 12),
            Text(
              formattedSecs,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions() {
    final supabase = ref.read(supabaseServiceProvider);
    return Visibility(
      visible: allPlayersFinished,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: SafeArea(
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
      ),
    );
  }
}
