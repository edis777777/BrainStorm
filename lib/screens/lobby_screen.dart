import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/room_models.dart';
import '../services/supabase_service.dart';
import '../state/app_providers.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String userId;
  final String playerName;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.playerName,
    required this.isHost,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  RoomModel? room;
  List<RoomPlayerModel> players = [];

  StreamSubscription? roomSub;
  StreamSubscription? playersSub;

  bool didNavigate = false;

  int buildSeed() => Random().nextInt(1 << 31);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final supabase = ref.read(supabaseServiceProvider);

    final initialRoom = await supabase.fetchRoom(roomId: widget.roomId);
    final initialPlayers = await supabase.fetchPlayers(roomId: widget.roomId);

    final roomModel = RoomModel.fromJson(initialRoom);
    final mappedPlayers = initialPlayers.map((e) => RoomPlayerModel.fromJson(e)).toList()
      ..sort((a, b) => a.playerName.compareTo(b.playerName));

    if (!mounted) return;
    setState(() {
      room = roomModel;
      players = mappedPlayers;
    });

    roomSub = supabase
        .roomRowStream(roomId: widget.roomId, initialRoom: initialRoom)
        .listen((newRoom) {
      if (!mounted) return;
      setState(() {
        room = RoomModel.fromJson(newRoom);
        // reset navigation guard when game state changes
        didNavigate = false;
      });
    });

    playersSub = supabase
        .playerRowsStream(roomId: widget.roomId, initialPlayers: initialPlayers)
        .listen((rows) {
      if (!mounted) return;
      setState(() {
        players = rows.map((e) => RoomPlayerModel.fromJson(e)).toList()
          ..sort((a, b) => a.playerName.compareTo(b.playerName));
      });

      final me = players.where((p) => p.userId == widget.userId).firstOrNull;
      if (me == null) return;

      if (!didNavigate) {
        if (me.finished) {
          didNavigate = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => LeaderboardScreen(
                roomId: widget.roomId,
                userId: widget.userId,
                playerName: widget.playerName,
                isHost: widget.isHost,
              ),
            ),
          );
        } else if (me.started) {
          didNavigate = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                roomId: widget.roomId,
                userId: widget.userId,
                playerName: widget.playerName,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    roomSub?.cancel();
    playersSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = room;
    final me = players.where((p) => p.userId == widget.userId).firstOrNull;

    final gameStarted = r?.gameStarted ?? false;
    final myReady = me?.ready ?? false;
    final myStarted = me?.started ?? false;
    final myFinished = me?.finished ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Lobby'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                r != null ? 'Code: ${r.code}' : '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: r == null || me == null
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final twoCol = constraints.maxWidth > 800;
                    return twoCol ? _twoColumn(gameStarted, myReady, myStarted, myFinished, r!.code) : _singleColumn(gameStarted, myReady, myStarted, myFinished, r!.code);
                  },
                ),
              ),
      ),
    );
  }

  Widget _singleColumn(bool gameStarted, bool myReady, bool myStarted, bool myFinished, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isHost) _hostQr(code),
        const SizedBox(height: 14),
        Text(
          gameStarted ? 'Game started' : 'Waiting for players',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _playersList(),
        const SizedBox(height: 16),
        if (!gameStarted) _readyButton(myReady)
        else if (!myStarted && !myFinished) _individualStartButton()
        else if (myFinished) _postGameNote()
        else _myStartedNote(),
      ],
    );
  }

  Widget _twoColumn(bool gameStarted, bool myReady, bool myStarted, bool myFinished, String code) {
    return Row(
      children: [
        Expanded(child: _playersList()),
        const SizedBox(width: 18),
        SizedBox(width: 260, child: Column(
          children: [
            if (widget.isHost) _hostQr(code) else const SizedBox.shrink(),
            const SizedBox(height: 14),
            if (!gameStarted) _readyButton(myReady)
            else if (!myStarted && !myFinished) _individualStartButton()
            else if (myFinished) _postGameNote()
            else _myStartedNote(),
          ],
        )),
      ],
    );
  }

  Widget _hostQr(String code) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Text('Host QR', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            QrImageView(data: code, size: 150, version: QrVersions.auto),
            const SizedBox(height: 10),
            Text(code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _playersList() {
    return Expanded(
      child: Card(
        color: Colors.white10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Players', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: players.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = players[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p.playerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: p.userId == widget.userId ? Theme.of(context).colorScheme.secondary : null,
                        ),
                      ),
                      subtitle: Text(
                        'Ready: ${p.ready ? "Yes" : "No"} | Started: ${p.started ? "Yes" : "No"} | Finished: ${p.finished ? "Yes" : "No"}',
                      ),
                    );
                  },
                ),
              ),
              if (widget.isHost)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _hostStartGameButton(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hostStartGameButton() {
    final gameStarted = room?.gameStarted ?? false;
    final allReady = players.isNotEmpty && players.every((p) => p.ready);
    return ElevatedButton(
      onPressed: (!gameStarted && allReady)
          ? () async {
              // Host starts the round, but each player still needs to click their own Start.
              final seed = buildSeed();
              final supabase = ref.read(supabaseServiceProvider);
              await supabase.hostStartGame(roomId: widget.roomId, gameSeed: seed);
            }
          : null,
      child: const Text('Start'),
    );
  }

  Widget _readyButton(bool myReady) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final supabase = ref.read(supabaseServiceProvider);
          await supabase.setReady(roomId: widget.roomId, userId: widget.userId, ready: !myReady);
        },
        child: Text(myReady ? 'Unready' : 'Ready'),
      ),
    );
  }

  Widget _individualStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          final supabase = ref.read(supabaseServiceProvider);
          // Navigate immediately so the timer starts closer to the click moment.
          didNavigate = true;
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => GameScreen(
                roomId: widget.roomId,
                userId: widget.userId,
                playerName: widget.playerName,
              ),
            ),
          );

          // Fire-and-forget: keeps timer aligned with the user click.
          unawaited(
            supabase.markStarted(roomId: widget.roomId, userId: widget.userId),
          );
        },
        child: const Text('Start'),
      ),
    );
  }

  Widget _myStartedNote() {
    return const SizedBox(
      width: double.infinity,
      child: Card(
        color: Colors.white10,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Starting...', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _postGameNote() {
    return const SizedBox(
      width: double.infinity,
      child: Card(
        color: Colors.white10,
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Showing leaderboard...', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final v in this) {
      return v;
    }
    return null;
  }
}

